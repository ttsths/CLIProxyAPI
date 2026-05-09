Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    npm ci
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    npm run typecheck
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    npx wrangler deploy
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}
