#Requires -Version 7.4
[CmdletBinding()]
param(
    [string]$ZCodeRoot = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.zcode'),
    [switch]$Login
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$uv = Get-Command uv.exe -ErrorAction SilentlyContinue
if (-not $uv) {
    $uv = Get-Command (Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Links/uv.exe') -ErrorAction SilentlyContinue
}
if (-not $uv) {
    throw 'uv is required. Run: winget install --id astral-sh.uv -e'
}
$uvExe = $uv.Source

function Get-SourceArchive {
    param([string]$Repository, [string]$Revision)

    Write-Host "Downloading $Repository..."
    $name = $Repository.Split('/')[-1]
    $zip = Join-Path $temp "$name.zip"
    & curl.exe --fail --location --silent --show-error --retry 3 --retry-all-errors --output $zip "https://codeload.github.com/$Repository/zip/$Revision"
    Expand-Archive -LiteralPath $zip -DestinationPath $temp
    Join-Path $temp "$name-$Revision"
}

function Read-JsonObject {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return @{} }
    $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    if ($data -isnot [System.Collections.IDictionary]) {
        throw "Expected a JSON object in $Path"
    }
    return $data
}

$ZCodeRoot = [System.IO.Path]::GetFullPath($ZCodeRoot)
$configPath = Join-Path $ZCodeRoot 'cli/config.json'
$config = Read-JsonObject $configPath
$config.mcp ??= @{}
$config.mcp.servers ??= @{}
if ($config.mcp.servers.Count -eq 0) {
    # ZCode ignores the compatible config once a native server is configured.
    $compatiblePath = Join-Path (Split-Path $ZCodeRoot) '.agents/mcp.json'
    $compatible = Read-JsonObject $compatiblePath
    if ($compatible.mcpServers) {
        $config.mcp.servers = $compatible.mcpServers
    }
}

$cnkiRevision = '637f6ebff76cb7477647dd8e53cc6879ec597e6f'
$runtime = Join-Path $ZCodeRoot "thesis-toolkit/$cnkiRevision"
$python = Join-Path $runtime 'Scripts/python.exe'
$cnkiExe = Join-Path $runtime 'Scripts/cnki-mcp.exe'
$existingCnki = $config.mcp.servers['cnki']
if ($existingCnki -and $existingCnki.command -ne $cnkiExe) {
    throw "A CNKI server already exists. Rename it in ZCode or remove it if it is no longer needed, then rerun. Config: $configPath"
}

$temp = (New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "zcode-thesis-$([guid]::NewGuid())")).FullName
try {
    $cnki = Get-SourceArchive 'SepineTam/cnki-mcp' $cnkiRevision
    $writing = Get-SourceArchive 'Norman-bury/research-writing-skill' '6f7959554b4614d879d79cb4ece9ed04a7c8a88c'
    $humanizer = Get-SourceArchive 'yzongy/zh-humanizer' '96075a69f6b7a12334679fd4a9ff997e0fd931ec'

    $sources = [ordered]@{
        'cnki-search' = (Join-Path $cnki 'plugins/skills/cnki-search')
        'zh-humanizer' = (Join-Path $humanizer 'zh-humanizer')
        'using-research-writing' = (Join-Path $writing 'skills/using-research-writing')
        'writing-humanities' = (Join-Path $writing 'skills/writing-humanities')
        'literature-review' = (Join-Path $writing 'skills/literature-review')
    }

    Write-Host 'Installing the isolated Python environment and Chromium...'
    if (-not (Test-Path -LiteralPath $python)) {
        & $uvExe venv --python 3.12 $runtime
    }
    & $uvExe pip install --python $python $cnki 'mcp==1.30.0' 'playwright==1.65.2' 'PyMuPDF'
    & $cnkiExe --help | Out-Null
    & $python -m playwright install chromium

    $reviewScripts = New-Item -ItemType Directory -Force -Path (Join-Path $sources['literature-review'] 'scripts')
    foreach ($scriptName in 'scholar_search.py', 'pdf_parser.py') {
        Copy-Item -LiteralPath (Join-Path $writing "scripts/$scriptName") -Destination $reviewScripts.FullName
    }

    $skillsRoot = (New-Item -ItemType Directory -Force -Path (Join-Path $ZCodeRoot 'skills')).FullName
    foreach ($name in $sources.Keys) {
        $destination = Join-Path $skillsRoot $name
        if (Test-Path -LiteralPath $destination) {
            Write-Host "Keeping existing skill: $name"
            continue
        }
        Copy-Item -LiteralPath $sources[$name] -Destination $destination -Recurse
        Write-Host "Installed skill: $name"
    }

    $config.mcp.servers['cnki'] ??= @{
        command = $cnkiExe
        args = @('serve', '--transport', 'stdio')
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $configPath) | Out-Null
    if (Test-Path -LiteralPath $configPath) {
        $backup = "$configPath.before-thesis-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff').bak"
        Copy-Item -LiteralPath $configPath -Destination $backup
    }
    $pendingConfig = "$configPath.thesis-$([guid]::NewGuid()).tmp"
    $config | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $pendingConfig -Encoding utf8
    [System.IO.File]::Move($pendingConfig, $configPath, $true)
    Write-Host 'Installation complete. Restart ZCode and open a new ZCode Agent chat.'
    Write-Host "Python for optional review scripts: $python"
    Write-Host "CNKI authentication command: & '$cnkiExe' init --profile default"

    if ($Login) {
        Write-Host 'Complete CNKI authentication in the browser opened by the CLI.'
        & $cnkiExe init --profile default
    }
} finally {
    $resolvedTemp = (Resolve-Path -LiteralPath $temp).ProviderPath
    if ($resolvedTemp -eq $temp) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
