param(
    [ValidateSet('auto','forward_plus','mobile','compatibility')]
    [string]$ForceRenderer = 'auto',
    [switch]$Editor,
    [switch]$Wait
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$GodotVersion = '4.7.2'
$AppVersion = '1.0.0-alpha22'
$GodotExe = Join-Path $Root "runtime\godot\Godot_v$GodotVersion-stable_win64.exe"
$SettingsPath = Join-Path $Root 'settings\config.json'
if (-not (Test-Path -LiteralPath $GodotExe)) {
    Write-Host 'Local Godot runtime is missing. Run install_windows.bat first.' -ForegroundColor Yellow
    exit 2
}

$Renderer = 'forward_plus'
if (Test-Path -LiteralPath $SettingsPath) {
    try {
        $cfg = Get-Content -Raw -LiteralPath $SettingsPath | ConvertFrom-Json
        if ($cfg.renderer) { $Renderer = [string]$cfg.renderer }
    } catch {
        Write-Host 'Warning: settings/config.json could not be parsed; using Forward+.' -ForegroundColor Yellow
    }
}
if ($ForceRenderer -ne 'auto') { $Renderer = $ForceRenderer }
$Method = switch ($Renderer) {
    'compatibility' { 'gl_compatibility' }
    'mobile' { 'mobile' }
    default { 'forward_plus' }
}
$Args = @('--path', $Root, '--rendering-method', $Method)
if ($Editor) { $Args += '--editor' }
Write-Host "Starting GAN Organism Arena $AppVersion using renderer: $Renderer ($Method)"
try {
    if ($Wait) {
        $Process = Start-Process -FilePath $GodotExe -ArgumentList $Args -WorkingDirectory $Root -PassThru -Wait
        exit $Process.ExitCode
    } else {
        Start-Process -FilePath $GodotExe -ArgumentList $Args -WorkingDirectory $Root | Out-Null
        exit 0
    }
} catch {
    Write-Host "Launch failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
