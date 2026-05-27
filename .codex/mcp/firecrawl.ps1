Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$envPath = Join-Path $repoRoot '.env'

if (-not (Test-Path -LiteralPath $envPath)) {
  Write-Host 'FIRECRAWL_API_KEY missing'
  exit 1
}

$envText = Get-Content -LiteralPath $envPath -Raw
$match = [System.Text.RegularExpressions.Regex]::Match(
  $envText,
  '(?m)^\s*(?:export\s+)?FIRECRAWL_API_KEY\s*=\s*(.+?)\s*$'
)

if (-not $match.Success) {
  Write-Host 'FIRECRAWL_API_KEY missing'
  exit 1
}

$apiKey = $match.Groups[1].Value.Trim()

if ($apiKey.StartsWith('"') -and $apiKey.EndsWith('"')) {
  $apiKey = $apiKey.Substring(1, $apiKey.Length - 2)
} elseif ($apiKey.StartsWith("'") -and $apiKey.EndsWith("'")) {
  $apiKey = $apiKey.Substring(1, $apiKey.Length - 2)
}

if ([string]::IsNullOrWhiteSpace($apiKey)) {
  Write-Host 'FIRECRAWL_API_KEY missing'
  exit 1
}

$env:FIRECRAWL_API_KEY = $apiKey
& npx -y firecrawl-mcp
