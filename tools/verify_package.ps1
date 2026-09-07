$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$ExpectedVersion = '1.0.0-alpha38'
$ExpectedDate = '2026-09-07'

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
    'game\world_save.gd',
    'game\application_test.gd',
    'game\ui_test.gd',
    'game\organism.gd',
    'game\organism_visual.gd',
    'game\genome.gd',
    'game\evolution_history.gd',
    'game\evolution_test.gd',
    'game\pause_test.gd',
    'game\texture_assets.gd',
    'game\skin_pattern.gd',
    'game\texture_test.gd',
    'game\audio_test.gd',
    'game\ecological_cycle_test.gd',
    'game\organism_surface.gdshader',
    'game\terrain_surface.gdshader',
    'textures\terrain\ground.png',
    'textures\organisms\skin.png',
    'textures\organisms\scales.png',
    'textures\organisms\fur.png',
    'textures\organisms\membrane.png',
    'textures\organisms\plates.png',
    'textures\organisms\mottle.png',
    'textures\terrain\silt.png',
    'textures\terrain\rock.png',
    'textures\terrain\organic_ground.png',
    'textures\terrain\seabed.png',
    'textures\terrain\shore.png',
    'textures\terrain\sand.png',
    'textures\terrain\grass.png',
    'game\dna_codec.gd',
    'game\cell_cycle.gd',
    'game\affect_model.gd',
    'game\thought_language.gd',
    'game\body_contact.gd',
    'game\body_support.gd',
    'game\app_log.gd',
    'game\localization.gd',
    'game\nutrient_field.gd',
    'game\obj_exporter.gd',
    'game\settings_store.gd',
    'game\tts_windows.gd',
    'game\support_test_terrain.gd',
    'game\support_test.gd',
    'game\posture_test.gd',
    'game\locomotion.gd',
    'game\navigation.gd',
    'game\navigation_test.gd',
    'game\follow_camera_solver.gd',
    'game\follow_camera_test.gd',
    'game\anatomical_rig.gd',
    'game\locomotion_test.gd',
    'game\interaction_test.gd',
    'game\physiology.gd',
    'game\experiment_api.gd',
    'game\ai_gateway.gd',
    'game\biology_test.gd',
    'game\experiment_test.gd',
    'integrations\arena_mcp.py',
    'integrations\arena_client.py',
    'integrations\arena_vklp.py',
    'integrations\verify_transcript.py',
    'run_mcp.bat',
    'run_ai_example.bat',
    'game\ecology_traits.gd',
    'game\habitat_model.gd',
    'game\ecology_system.gd',
    'game\ecology_test.gd',
    'game\surface_test.gd',
    'game\life_cycle.gd',
    'game\reproduction_system.gd',
    'game\reproduction_test_world.gd',
    'game\life_cycle_test.gd',
    'game\water_surface.gdshader',
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

# Every optional source declared by the texture registry must ship with the
# package, including tissue/material fallbacks that are not preloaded scripts.
$TextureRegistry = Get-Content -Raw -LiteralPath (Join-Path $Root 'game\texture_assets.gd')
$TextureMatches = [regex]::Matches($TextureRegistry, '"res://(?<path>textures/[^"\r\n]+\.png)"')
if ($TextureMatches.Count -ne 33) { throw "Expected 33 registered PNG textures, found $($TextureMatches.Count)" }
foreach ($TextureMatch in $TextureMatches) {
    $RelativeTexture = $TextureMatch.Groups['path'].Value -replace '/', '\'
    Require-File $RelativeTexture
    $TextureFile = Get-Item -LiteralPath (Join-Path $Root $RelativeTexture)
    if ($TextureFile.Length -gt 1MB) { throw "Optional texture exceeds 1 MiB: $RelativeTexture" }
}

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
# Conservative source rule for this project: property names declared as typed
# arrays must receive an explicitly typed value, never a bare Array literal.
# Dynamic property assignment otherwise passes parsing and fails at runtime.
$TypedArrayMembers = @{}
foreach ($Gd in $GdFiles) {
    $Source = Get-Content -Raw -LiteralPath $Gd.FullName
    foreach ($Binding in [regex]::Matches($Source, '(?m)^var\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*Array\s*\[[^\]\r\n]+\]')) {
        $TypedArrayMembers[$Binding.Groups['name'].Value] = $true
    }
}
foreach ($Gd in $GdFiles) {
    $Text = Get-Content -Raw -LiteralPath $Gd.FullName
    foreach ($Assignment in [regex]::Matches($Text, '(?m)\.(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*\[')) {
        $MemberName = $Assignment.Groups['name'].Value
        if ($TypedArrayMembers.ContainsKey($MemberName)) {
            throw "Typed array assignment regression in $($Gd.Name): .$MemberName must receive an explicitly typed array value."
        }
    }
    if ($Text -match 'func\s+[^\r\n(]+\([^\r\n)]*:=' ) {
        throw "Invalid GDScript default-argument ':=' syntax in $($Gd.FullName)"
    }
    if ($Text -match '1\.0\.0-alpha(?:[1-9]|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24)(?![0-9])') {
        throw "Stale pre-alpha25 version string in $($Gd.FullName)"
    }

    if ($Text -match '(?:ecology|eco)\.configure\([^\r\n]*,\s*\[' -or $Text -match '\.set_habitat\([^\r\n]*,\s*\[') {
        throw "Typed resource-array regression in $($Gd.FullName): pass an explicit Array[Vector3] variable."
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
