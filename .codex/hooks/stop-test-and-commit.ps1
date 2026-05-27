param()

$ErrorActionPreference = 'Stop'

function Write-HookJson {
  param([Parameter(Mandatory=$true)][object]$Payload)
  $Payload | ConvertTo-Json -Depth 10 -Compress
}

function Get-RepoRoot {
  (& git rev-parse --show-toplevel).Trim()
}

function Add-HookLog {
  param([Parameter(Mandatory=$true)][string]$Message)

  $repoRoot = Get-RepoRoot
  $logPath = Join-Path $repoRoot '.codex/hooks/hook.log'
  Add-Content -Path $logPath -Encoding UTF8 -Value "$(Get-Date -Format o) $Message"
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
    $normalized -match '^html-builder/AGENTS\.md$' -or
    $normalized -match '^test-runner/AGENTS\.md$'
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
$name = (& git config --get user.name).Trim()
$email = (& git config --get user.email).Trim()

if (-not $name -or -not $email) {
  $reason = 'BLOCKED: git user.name/user.email is missing; auto-commit disabled.'
  Add-HookLog "[HOOK] Stop blocked: $reason"
  Write-HookJson @{
    continue = $false
    stopReason = $reason
  }
  exit 0
}

$statusLines = & git -C $repoRoot status --porcelain --untracked-files=all

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
  $changedFiles.Add($path)
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

& git -C $repoRoot add . *> $null
& git -C $repoRoot commit -m 'auto: Codex generated update' *> $null
$commitHash = (& git -C $repoRoot rev-parse --short HEAD).Trim()
Add-HookLog "[HOOK] Stop commit created: $commitHash"

Write-HookJson @{
  continue = $true
}
