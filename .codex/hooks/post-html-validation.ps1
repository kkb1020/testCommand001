param()

$ErrorActionPreference = 'Stop'

function Write-HookJson {
  param([Parameter(Mandatory=$true)][object]$Payload)
  $Payload | ConvertTo-Json -Depth 8 -Compress
}

function Add-HookLog {
  param([Parameter(Mandatory=$true)][string]$Message)

  $repoRoot = (& git rev-parse --show-toplevel).Trim()
  $logPath = Join-Path $repoRoot '.codex/hooks/hook.log'
  Add-Content -Path $logPath -Encoding UTF8 -Value "$(Get-Date -Format o) $Message"
}

function Get-RepoRoot {
  (& git rev-parse --show-toplevel).Trim()
}

Add-HookLog '[HOOK] PostToolUse html validation started'

$repoRoot = Get-RepoRoot
$indexPath = Join-Path $repoRoot 'index.html'
$status = & git -C $repoRoot status --porcelain -- index.html

if (-not $status) {
  Add-HookLog '[HOOK] PostToolUse skipped: index.html not changed'
  Write-HookJson @{
    continue = $true
    hookSpecificOutput = @{
      hookEventName = 'PostToolUse'
      additionalContext = 'index.html not changed; skipped.'
    }
  }
  exit 0
}

if (-not (Test-Path -LiteralPath $indexPath)) {
  Add-HookLog '[HOOK] PostToolUse failed: index.html missing'
  Write-HookJson @{
    continue = $false
    stopReason = 'index.html is missing.'
    hookSpecificOutput = @{
      hookEventName = 'PostToolUse'
      additionalContext = 'index.html validation failed.'
    }
  }
  exit 0
}

$content = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
$required = @('<html', '<head', '<body')
$missing = @()

foreach ($needle in $required) {
  if ($content -notmatch [regex]::Escape($needle)) {
    $missing += $needle
  }
}

if ($missing.Count -gt 0) {
  $reason = 'index.html is missing required tags: ' + ($missing -join ', ')
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

Add-HookLog '[HOOK] PostToolUse success: index.html basic structure verified'
Write-HookJson @{
  continue = $true
  hookSpecificOutput = @{
    hookEventName = 'PostToolUse'
    additionalContext = 'index.html basic structure verified.'
  }
}
