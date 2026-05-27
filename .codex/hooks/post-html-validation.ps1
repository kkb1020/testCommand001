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

function Write-HookJson {
  param([Parameter(Mandatory=$true)][object]$Payload)
  $Payload | ConvertTo-Json -Depth 8 -Compress
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

function Get-ChangedHtmlFiles {
  param(
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$true)][string]$GitExe
  )

  $statusLines = & $GitExe -C $RepoRoot status --porcelain --untracked-files=all
  $htmlFiles = New-Object System.Collections.Generic.List[string]

  foreach ($line in $statusLines) {
    if ($line.Length -lt 4) { continue }

    $path = $line.Substring(3)
    if ($path -match ' -> ') {
      $path = ($path -split ' -> ')[-1]
    }

    if ($path -match '\.html$') {
      $htmlFiles.Add($path)
    }
  }

  return $htmlFiles
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

Add-HookLog '[HOOK] PostToolUse html validation started'

$repoRoot = Get-RepoRoot
$gitExe = Get-GitExe

if (-not $gitExe) {
  $reason = 'FATAL: git executable not found in expected locations.'
  Add-HookLog "[HOOK] PostToolUse failed: $reason"
  Write-HookJson @{
    continue = $false
    stopReason = $reason
    hookSpecificOutput = @{
      hookEventName = 'PostToolUse'
      additionalContext = 'Git executable lookup failed.'
    }
  }
  exit 0
}

$htmlFiles = Get-ChangedHtmlFiles -RepoRoot $repoRoot -GitExe $gitExe

if (-not $htmlFiles -or $htmlFiles.Count -eq 0) {
  Add-HookLog '[HOOK] PostToolUse skipped: no changed HTML files'
  Write-HookJson @{
    continue = $true
    hookSpecificOutput = @{
      hookEventName = 'PostToolUse'
      additionalContext = 'No changed HTML files to validate.'
    }
  }
  exit 0
}

foreach ($file in $htmlFiles) {
  $fullPath = Join-Path $repoRoot $file
  if (-not (Test-Path -LiteralPath $fullPath)) {
    $reason = "HTML file missing: $file"
    Add-HookLog "[HOOK] PostToolUse failed: $reason"
    Write-HookJson @{
      continue = $false
      stopReason = $reason
      hookSpecificOutput = @{
        hookEventName = 'PostToolUse'
        additionalContext = 'HTML file validation failed.'
      }
    }
    exit 0
  }

  if (-not (Test-HtmlFile -Path $fullPath)) {
    $reason = "HTML basic structure check failed for $file"
    Add-HookLog "[HOOK] PostToolUse failed: $reason"
    Write-HookJson @{
      continue = $false
      stopReason = $reason
      hookSpecificOutput = @{
        hookEventName = 'PostToolUse'
        additionalContext = 'HTML basic structure check failed.'
      }
    }
    exit 0
  }
}

Add-HookLog ("[HOOK] PostToolUse success: validated HTML files: " + ($htmlFiles -join ', '))
Write-HookJson @{
  continue = $true
  hookSpecificOutput = @{
    hookEventName = 'PostToolUse'
    additionalContext = 'Changed HTML files basic structure verified.'
  }
}
