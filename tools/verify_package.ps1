$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$ExpectedVersion = '1.0.0-alpha12'
$ExpectedDate = '2026-09-01'

function Require-File([string]$RelativePath) {
    $Path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file is missing: $RelativePath"
    }
}

Write-Host 'Static package verification...'
$Required = @(
    'project.godot',
    'VERSION.txt',
    'LICENSE.txt',
    'README.md',
    'scenes\Main.tscn',
    'scenes\SelfTest.tscn',
    'scenes\SmokeTest.tscn',
    'game\main.gd',
    'game\sim_world.gd',
    'game\organism.gd',
    'game\organism_visual.gd',
    'game\genome.gd',
    'game\ecology_traits.gd',
    'game\habitat_model.gd',
    'game\ecology_system.gd',
    'game\ecology_test.gd',
    'game\surface_test.gd',
    'game\arena_ui.gd',
    'game\free_swim_camera.gd',
    'game\habitat_visual.gd',
    'game\audio_ecosystem.gd',
    'game\self_test.gd',
    'game\smoke_test.gd',
    'game\parse_test.gd',
    'run_parse_test.bat',
    'language\en.json',
    'language\de.json',
    'language\fr.json'
)
foreach ($File in $Required) { Require-File $File }

$VersionText = Get-Content -Raw -LiteralPath (Join-Path $Root 'VERSION.txt')
if ($VersionText -notmatch [regex]::Escape($ExpectedVersion)) { throw "VERSION.txt does not contain $ExpectedVersion" }
if ($VersionText -notmatch [regex]::Escape($ExpectedDate)) { throw "VERSION.txt does not contain release date $ExpectedDate" }

$ProjectText = Get-Content -Raw -LiteralPath (Join-Path $Root 'project.godot')
if ($ProjectText -notmatch ('config/version="' + [regex]::Escape($ExpectedVersion) + '"')) { throw 'project.godot version mismatch' }
if ($ProjectText -notmatch 'run/main_scene="res://scenes/Main.tscn"') { throw 'project.godot main scene is missing' }
$SelfTestScene = Get-Content -Raw -LiteralPath (Join-Path $Root 'scenes\SelfTest.tscn')
if ($SelfTestScene -notmatch 'res://game/self_test.gd') { throw 'SelfTest.tscn is not wired to game/self_test.gd' }
$SmokeTestScene = Get-Content -Raw -LiteralPath (Join-Path $Root 'scenes\SmokeTest.tscn')
if ($SmokeTestScene -notmatch 'res://game/smoke_test.gd') { throw 'SmokeTest.tscn is not wired to game/smoke_test.gd' }

foreach ($Code in @('en','de','fr')) {
    $Path = Join-Path $Root "language\$Code.json"
    try {
        $null = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    } catch {
        throw "Invalid JSON in language\$Code.json : $($_.Exception.Message)"
    }
}

# Parser regression checks: reject syntax/identifier mistakes that previously escaped static packaging.
# The latter was the exact alpha3 parser failure hidden behind organism.gd preload.
$GdFiles = Get-ChildItem -LiteralPath (Join-Path $Root 'game') -Filter '*.gd' -File -Recurse
foreach ($Gd in $GdFiles) {
    $Text = Get-Content -Raw -LiteralPath $Gd.FullName
    if ($Text -match 'func\s+[^\r\n(]+\([^\r\n)]*:=' ) {
        throw "Invalid GDScript default-argument ':=' syntax in $($Gd.FullName)"
    }
    if ($Text -match '1\.0\.0-alpha(?:[1-9]|10|11)(?![0-9])') {
        throw "Stale pre-alpha12 version string in $($Gd.FullName)"
    }

    # Check loop bindings as well as var/const declarations. Alpha10 used
    # `for trait in ...`, which Godot 4.7.2 rejects as a reserved identifier.
    $Reserved = 'and|as|assert|await|break|breakpoint|class|class_name|const|continue|elif|else|enum|extends|false|for|func|if|in|is|match|namespace|not|null|or|pass|return|self|signal|static|super|trait|true|var|void|while|yield'
    $BadVar = [regex]::Match($Text, "(?m)^\s*(?:var|const|for)\s+(?<name>(?:$Reserved))\b")
    if ($BadVar.Success) {
        throw "Reserved GDScript keyword '$($BadVar.Groups['name'].Value)' used as variable, constant or loop name in $($Gd.FullName)"
    }
    $FuncMatches = [regex]::Matches($Text, '(?m)^\s*(?:static\s+)?func\s+[A-Za-z_][A-Za-z0-9_]*\s*\((?<params>[^)]*)\)')
    foreach ($FuncMatch in $FuncMatches) {
        $Params = $FuncMatch.Groups['params'].Value -split ','
        foreach ($Param in $Params) {
            $NameMatch = [regex]::Match($Param, '^\s*(?<name>[A-Za-z_][A-Za-z0-9_]*)')
            if ($NameMatch.Success -and $NameMatch.Groups['name'].Value -match "^(?:$Reserved)$") {
                throw "Reserved GDScript keyword '$($NameMatch.Groups['name'].Value)' used as function parameter in $($Gd.FullName)"
            }
        }
    }

    # Verify every local res:// preload target exists in the package.
    $Matches = [regex]::Matches($Text, 'preload\("res://([^"\r\n]+)"\)')
    foreach ($Match in $Matches) {
        $Rel = $Match.Groups[1].Value -replace '/', '\'
        $Target = Join-Path $Root $Rel
        if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) {
            throw "Missing preload target '$Rel' referenced by $($Gd.Name)"
        }
    }
}

# Current-version metadata must agree. Historical changelog entries are allowed.
$CurrentVersionFiles = @(
    'VERSION.txt',
    'project.godot',
    'install_windows.bat',
    'tools\install_godot.ps1',
    'tools\launch.ps1',
    'README.md'
)
foreach ($Rel in $CurrentVersionFiles) {
    $Text = Get-Content -Raw -LiteralPath (Join-Path $Root $Rel)
    if ($Text -notmatch [regex]::Escape($ExpectedVersion)) {
        throw "Current version $ExpectedVersion missing from $Rel"
    }
}

# Make sure persistent/output folders can be created in the unpacked project.
foreach ($Dir in @('settings','logs','logs\install','exports\obj','screenshots','runtime\godot')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $Dir) | Out-Null
}

Write-Host "Static package verification OK: GAN Organism Arena $ExpectedVersion ($ExpectedDate)"
exit 0
