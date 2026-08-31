$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$AppVersion = '1.0.0-alpha6'
$ReleaseDate = '2026-09-01'
$GodotVersion = '4.7.2'
$RuntimeDir = Join-Path $Root 'runtime\godot'
$LogsDir = Join-Path $Root 'logs\install'
$ZipName = "Godot_v$GodotVersion-stable_win64.exe.zip"
$ZipPath = Join-Path $RuntimeDir $ZipName
$GodotExe = Join-Path $RuntimeDir "Godot_v$GodotVersion-stable_win64.exe"
$GodotConsole = Join-Path $RuntimeDir "Godot_v$GodotVersion-stable_win64_console.exe"
$GitHubUrl = "https://github.com/godotengine/godot/releases/download/$GodotVersion-stable/$ZipName"
$MirrorUrl = "https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=win64.exe.zip&version=$GodotVersion"
$ExpectedSha256 = '731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953'

# GitHub/CDN downloads on older Windows/PowerShell installations can otherwise
# negotiate legacy TLS. Force TLS 1.2 for a predictable first-time install.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

New-Item -ItemType Directory -Force -Path $RuntimeDir, $LogsDir, (Join-Path $Root 'logs'), (Join-Path $Root 'settings'), (Join-Path $Root 'exports\obj'), (Join-Path $Root 'screenshots') | Out-Null
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogPath = Join-Path $LogsDir "install_$Stamp.log"
Start-Transcript -Path $LogPath -Force | Out-Null

function Download-File([string]$Url, [string]$Target) {
    Write-Host "  Download: $Url"
    if (Test-Path -LiteralPath $Target) { Remove-Item -Force -LiteralPath $Target }
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Target -MaximumRedirection 10
        return
    } catch {
        Write-Host "  Invoke-WebRequest failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    $Bits = Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue
    if ($Bits) {
        Write-Host '  Trying Windows BITS...'
        Start-BitsTransfer -Source $Url -Destination $Target -ErrorAction Stop
        return
    }
    throw "Could not download $Url with Invoke-WebRequest or BITS."
}

function Verify-Archive([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToUpperInvariant()
    if ($Hash -eq $ExpectedSha256) { return $true }
    Write-Host "  Runtime archive checksum mismatch: $Hash" -ForegroundColor Yellow
    Remove-Item -Force -LiteralPath $Path -ErrorAction SilentlyContinue
    return $false
}

try {
    Write-Host '============================================================'
    Write-Host "  GAN Organism Arena v$AppVersion ($ReleaseDate)"
    Write-Host "  Portable Godot $GodotVersion - Windows Installer"
    Write-Host '============================================================'
    Write-Host "Root: $Root"
    Write-Host "Local Godot runtime: $RuntimeDir"
    Write-Host "Install log: $LogPath"
    Write-Host ''

    Write-Host '[1/8] Verifying package files and language JSON...'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify_package.ps1')
    if ($LASTEXITCODE -ne 0) { throw "Static package verification failed with exit code $LASTEXITCODE." }

    Write-Host '[2/8] Preparing portable Godot runtime...'
    if (-not (Test-Path -LiteralPath $GodotExe)) {
        if (-not (Verify-Archive $ZipPath)) {
            $Downloaded = $false
            foreach ($Url in @($GitHubUrl, $MirrorUrl)) {
                try {
                    Download-File $Url $ZipPath
                    if (Verify-Archive $ZipPath) {
                        $Downloaded = $true
                        break
                    }
                } catch {
                    Write-Host "  Download source failed: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
            if (-not $Downloaded) {
                throw "Unable to obtain a checksum-valid Godot $GodotVersion runtime archive. If your network blocks GitHub, manually place $ZipName in runtime\godot\ and rerun this installer."
            }
        } else {
            Write-Host '  Reusing checksum-verified runtime archive.'
        }
        Write-Host '  Extracting portable runtime...'
        try {
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $RuntimeDir -Force
        } catch {
            throw "Could not extract the Godot runtime archive: $($_.Exception.Message)"
        }
    } else {
        Write-Host '  Portable runtime already present.'
    }

    if (-not (Test-Path -LiteralPath $GodotExe)) { throw "Godot executable not found after extraction: $GodotExe" }
    if (-not (Test-Path -LiteralPath $GodotConsole)) {
        Write-Host '  Console executable not present; verification will use the normal executable.' -ForegroundColor Yellow
        $GodotConsole = $GodotExe
    }

    Write-Host '[3/8] Checking Godot runtime version...'
    $VersionOutput = (& $GodotConsole --version 2>&1 | Out-String).Trim()
    Write-Host "  Runtime reports: $VersionOutput"
    if ($VersionOutput -notmatch '^4\.7\.2') { throw "Unexpected Godot runtime version: $VersionOutput" }

    Write-Host '[4/8] Parsing every core GDScript with per-file diagnostics...'
    $ParseLog = Join-Path $LogsDir "parse_$Stamp.log"
    & $GodotConsole --headless --path $Root --script res://game/parse_test.gd --rendering-method gl_compatibility 2>&1 | Tee-Object -FilePath $ParseLog
    $ParseExit = $LASTEXITCODE
    $ParseText = Get-Content -Raw -LiteralPath $ParseLog
    if ($ParseExit -ne 0) { throw "GDScript parse test failed with exit code $ParseExit. See $ParseLog" }
    if ($ParseText -match 'SCRIPT ERROR:' -or $ParseText -match 'Parse Error:' -or $ParseText -match 'PARSE FAILED:' -or $ParseText -match 'Failed to load script') {
        throw "GDScript parse test reported a parser/script error even though Godot returned exit code 0. See $ParseLog"
    }

    Write-Host '[5/8] Running artificial-life morphology/genome/language self-test...'
    $SelfTestLog = Join-Path $LogsDir "selftest_$Stamp.log"
    & $GodotConsole --headless --path $Root --rendering-method gl_compatibility --scene res://scenes/SelfTest.tscn 2>&1 | Tee-Object -FilePath $SelfTestLog
    $SelfTestExit = $LASTEXITCODE
    $SelfTestText = Get-Content -Raw -LiteralPath $SelfTestLog
    if ($SelfTestExit -ne 0) { throw "Artificial-life self-test failed with exit code $SelfTestExit. See $SelfTestLog" }
    if ($SelfTestText -match 'SCRIPT ERROR:' -or $SelfTestText -match 'Parse Error:' -or $SelfTestText -match 'SELFTEST ERROR:' -or $SelfTestText -match 'Failed to load script') {
        throw "Artificial-life self-test reported a script/self-test error even though Godot returned exit code 0. See $SelfTestLog"
    }

    Write-Host '[6/8] Running short Compatibility/OpenGL runtime smoke test...'
    $SmokeLog = Join-Path $LogsDir "smoke_$Stamp.log"
    & $GodotConsole --headless --path $Root --quit-after 90 --rendering-method gl_compatibility 2>&1 | Tee-Object -FilePath $SmokeLog
    $SmokeExit = $LASTEXITCODE
    if ($SmokeExit -ne 0) { throw "Compatibility runtime smoke test failed with exit code $SmokeExit." }
    $SmokeText = Get-Content -Raw -LiteralPath $SmokeLog
    if ($SmokeText -match 'SCRIPT ERROR:' -or $SmokeText -match 'Parse Error:' -or $SmokeText -match 'Failed to load script') {
        throw "Compatibility runtime smoke test reported a script error. See $SmokeLog"
    }

    Write-Host '[7/8] Writing installed-runtime marker...'
    $Marker = @(
        "GAN Organism Arena $AppVersion",
        "Release date: $ReleaseDate",
        "Godot runtime: $GodotVersion",
        "Installed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Runtime archive SHA256: $ExpectedSha256"
    ) -join "`r`n"
    Set-Content -LiteralPath (Join-Path $RuntimeDir 'INSTALLED_RUNTIME.txt') -Value $Marker -Encoding UTF8

    Write-Host '[8/8] Installation complete.'
    Write-Host ''
    Write-Host 'The engine is portable and local to this project directory.'
    Write-Host 'No system-wide Godot installation, Python environment, registry installation, or administrator rights are required.'
    Write-Host 'After this first online installation the application can run offline.'
    Write-Host "Runtime: $GodotExe"
    Write-Host "Logs: $(Join-Path $Root 'logs')"
    Write-Host ''
    exit 0
} catch {
    Write-Host ''
    Write-Host 'INSTALLATION FAILED:' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "See: $LogPath"
    exit 1
} finally {
    try { Stop-Transcript | Out-Null } catch { }
}
