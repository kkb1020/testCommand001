param()

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
  (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}

function Get-GitExe {
  $candidates = @(
    $env:GIT_EXE,
    'C:\Program Files\Git\cmd\git.exe',
    'C:\Program Files\Git\bin\git.exe',
    'C:\Program Files\Git\mingw64\bin\git.exe'
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  $gitCommand = Get-Command git -ErrorAction SilentlyContinue
  if ($gitCommand -and $gitCommand.Source) {
    return $gitCommand.Source
  }

  $gitWhere = & where.exe git 2>$null | Select-Object -First 1
  if ($gitWhere) {
    return $gitWhere.Trim()
  }

  return $null
}

function Invoke-GitCommand {
  param(
    [Parameter(Mandatory=$true)][string]$GitExe,
    [Parameter(Mandatory=$true)][string]$WorkingDirectory,
    [Parameter(Mandatory=$true)][string[]]$Arguments,
    [switch]$CaptureStdout
  )

  function Quote-Argument {
    param([Parameter(Mandatory=$true)][string]$Argument)

    if ($Argument -match '[\s"]') {
      return '"' + ($Argument -replace '"', '\"') + '"'
    }

    return $Argument
  }

  $argumentString = ($Arguments | ForEach-Object { Quote-Argument -Argument $_ }) -join ' '
  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $stderrPath = [System.IO.Path]::GetTempFileName()

  try {
    $process = Start-Process `
      -FilePath $GitExe `
      -ArgumentList $argumentString `
      -WorkingDirectory $WorkingDirectory `
      -NoNewWindow `
      -Wait `
      -PassThru `
      -RedirectStandardOutput $stdoutPath `
      -RedirectStandardError $stderrPath

    if ($process.ExitCode -ne 0) {
      $stderr = ''
      if (Test-Path -LiteralPath $stderrPath) {
        $stderr = (Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue).Trim()
      }
      if ($stderr) {
        throw "git exited with code $($process.ExitCode): $stderr"
      }
      throw "git exited with code $($process.ExitCode)"
    }

    if ($CaptureStdout) {
      return (Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue)
    }

    return $null
  } finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
  }
}

function Write-HookJson {
  param([Parameter(Mandatory=$true)][object]$Payload)
  $Payload | ConvertTo-Json -Depth 10 -Compress
}

function Add-HookLog {
  param([Parameter(Mandatory=$true)][string]$Message)

  try {
    $repoRoot = Get-RepoRoot
    $logPath = Join-Path $repoRoot '.codex/hooks/hook.log'
    Add-Content -Path $logPath -Encoding UTF8 -Value "$(Get-Date -Format o) $Message"
  } catch {
    return
  }
}

function Test-AllowedPath {
  param([Parameter(Mandatory=$true)][string]$RelativePath)

  $normalized = $RelativePath -replace '\\', '/'
  return (
    $normalized -match '^index\.html$' -or
    $normalized -match '^(?:.*\.html|.*\.py)$' -or
    $normalized -match '^\.codex/hooks\.json$' -or
    $normalized -match '^\.codex/hooks/.*$' -or
    $normalized -match '^\.codex/agents/.*\.toml$' -or
    $normalized -match '^\.agents/skills/.*\.md$' -or
    $normalized -match '^html-builder/AGENTS\.md$' -or
    $normalized -match '^test-runner/AGENTS\.md$'
  )
}

function Test-IgnoredPath {
  param([Parameter(Mandatory=$true)][string]$RelativePath)

  $normalized = $RelativePath -replace '\\', '/'
  return (
    $normalized -match '(^|/)\.env(\..*)?$' -or
    $normalized -match '^\.codex/hooks/hook\.log$'
  )
}

function Test-HtmlFile {
  param([Parameter(Mandatory=$true)][string]$Path)

  $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  $required = @('<html', '<head', '<body')
  foreach ($needle in $required) {
    if ($content -notmatch [regex]::Escape($needle)) {
      return $false
    }
  }
  return $true
}

function Test-PythonFile {
  param([Parameter(Mandatory=$true)][string]$Path)

  try {
    & python -m py_compile $Path
    return $true
  } catch {
    try {
      & py -3 -m py_compile $Path
      return $true
    } catch {
      return $false
    }
  }
}

Add-HookLog '[HOOK] Stop test and commit started'

$repoRoot = Get-RepoRoot
$gitExe = Get-GitExe

if (-not $gitExe) {
  $reason = 'BLOCKED: git executable not found in expected locations.'
  Add-HookLog "[HOOK] Stop blocked: $reason"
  Write-HookJson @{
    continue = $false
    stopReason = $reason
  }
  exit 0
}

$name = (Invoke-GitCommand -GitExe $gitExe -WorkingDirectory $repoRoot -Arguments @('config', '--get', 'user.name') -CaptureStdout).Trim()
$email = (Invoke-GitCommand -GitExe $gitExe -WorkingDirectory $repoRoot -Arguments @('config', '--get', 'user.email') -CaptureStdout).Trim()

if (-not $name -or -not $email) {
  $reason = 'BLOCKED: git user.name/user.email is missing; auto-commit disabled.'
  Add-HookLog "[HOOK] Stop blocked: $reason"
  Write-HookJson @{
    continue = $false
    stopReason = $reason
  }
  exit 0
}

$statusOutput = Invoke-GitCommand -GitExe $gitExe -WorkingDirectory $repoRoot -Arguments @('-C', $repoRoot, 'status', '--porcelain', '--untracked-files=all') -CaptureStdout
$statusLines = @()
if ($statusOutput) {
  $statusLines = $statusOutput -split "`r?`n" | Where-Object { $_ }
}

if (-not $statusLines) {
  Add-HookLog '[HOOK] Stop success: no changes to commit'
  Write-HookJson @{
    continue = $true
  }
  exit 0
}

$changedFiles = New-Object System.Collections.Generic.List[string]
foreach ($line in $statusLines) {
  if ($line.Length -lt 4) { continue }
  $path = $line.Substring(3)
  if ($path -match ' -> ') {
    $path = ($path -split ' -> ')[-1]
  }
  if (Test-IgnoredPath -RelativePath $path) {
    continue
  }
  $changedFiles.Add($path)
}

if ($changedFiles.Count -eq 0) {
  Add-HookLog '[HOOK] Stop success: only ignored paths changed'
  Write-HookJson @{
    continue = $true
  }
  exit 0
}

$disallowed = @()
foreach ($file in $changedFiles) {
  if (-not (Test-AllowedPath -RelativePath $file)) {
    $disallowed += $file
  }
}

if ($disallowed.Count -gt 0) {
  $reason = 'BLOCKED: disallowed changed files detected: ' + ($disallowed -join ', ')
  Add-HookLog "[HOOK] Stop blocked: $reason"
  Write-HookJson @{
    continue = $false
    stopReason = $reason
  }
  exit 0
}

$htmlFiles = $changedFiles | Where-Object { $_ -match '\.html$' }
$pythonFiles = $changedFiles | Where-Object { $_ -match '\.py$' }

foreach ($file in $htmlFiles) {
  $fullPath = Join-Path $repoRoot $file
  if (-not (Test-Path -LiteralPath $fullPath)) {
    $reason = "BLOCKED: HTML file missing: $file"
    Add-HookLog "[HOOK] Stop blocked: $reason"
    Write-HookJson @{
      continue = $false
      stopReason = $reason
    }
    exit 0
  }

  if (-not (Test-HtmlFile -Path $fullPath)) {
    $reason = "BLOCKED: HTML basic structure check failed for $file"
    Add-HookLog "[HOOK] Stop blocked: $reason"
    Write-HookJson @{
      continue = $false
      stopReason = $reason
    }
    exit 0
  }
}

foreach ($file in $pythonFiles) {
  $fullPath = Join-Path $repoRoot $file
  if (-not (Test-PythonFile -Path $fullPath)) {
    $reason = "BLOCKED: Python bytecode validation failed for $file"
    Add-HookLog "[HOOK] Stop blocked: $reason"
    Write-HookJson @{
      continue = $false
      stopReason = $reason
    }
    exit 0
  }
}

foreach ($file in $changedFiles) {
  [void](Invoke-GitCommand -GitExe $gitExe -WorkingDirectory $repoRoot -Arguments @('-C', $repoRoot, 'add', '--', $file))
}
[void](Invoke-GitCommand -GitExe $gitExe -WorkingDirectory $repoRoot -Arguments @('-C', $repoRoot, 'commit', '-m', 'auto: Codex generated update'))
$commitHash = (Invoke-GitCommand -GitExe $gitExe -WorkingDirectory $repoRoot -Arguments @('-C', $repoRoot, 'rev-parse', '--short', 'HEAD') -CaptureStdout).Trim()
Add-HookLog "[HOOK] Stop commit created: $commitHash"

Write-HookJson @{
  continue = $true
}
