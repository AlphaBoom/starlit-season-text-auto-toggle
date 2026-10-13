[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GameDirectory,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$repoDirectory = Split-Path -Parent $PSScriptRoot
$runtime = Get-Content -LiteralPath (Join-Path $repoDirectory 'runtime.json') -Raw | ConvertFrom-Json
$gameRoot = (Resolve-Path -LiteralPath $GameDirectory).Path
$binaryDirectory = Join-Path $gameRoot 'StarlitSeason\Binaries\Win64'
$executable = Join-Path $binaryDirectory 'StarlitSeason-Win64-Shipping.exe'
$loaderDirectory = Join-Path $binaryDirectory 'ue4ss'
$loader = Join-Path $loaderDirectory 'UE4SS.dll'
$proxy = Join-Path $binaryDirectory 'dwmapi.dll'

if (!(Test-Path -LiteralPath $executable) -or
    (Get-FileHash -LiteralPath $executable).Hash -ne $runtime.gameExeSha256) {
    throw 'Unsupported game executable. This release targets Steam Starlit Season 1.61.'
}
foreach ($entry in @(@($loader, $runtime.dllSha256), @($proxy, $runtime.proxySha256))) {
    if ((Test-Path -LiteralPath $entry[0]) -and (Get-FileHash -LiteralPath $entry[0]).Hash -ne $entry[1]) {
        throw "A different loader already exists: $($entry[0]). Resolve the conflict before installing."
    }
}
if ((Test-Path -LiteralPath (Join-Path $binaryDirectory 'xinput1_3.dll')) -and
    (Test-Path -LiteralPath (Join-Path $binaryDirectory 'UE4SS.dll'))) {
    throw 'An older xinput UE4SS installation was found. Disable it before installing this loader.'
}
if ($CheckOnly) {
    Write-Output "Compatible game. Required UE4SS: $($runtime.version). No files changed."
    return
}
if (Get-Process -Name 'StarlitSeason-Win64-Shipping' -ErrorAction SilentlyContinue) {
    throw 'Close the game before installing or updating the mod.'
}

# Original files are retained once, across subsequent updates.
$backupDirectory = Join-Path $binaryDirectory '.TextAutoToggleBackup'
function Backup-File([string]$RelativePath) {
    $source = Join-Path $binaryDirectory $RelativePath
    $backup = Join-Path $backupDirectory $RelativePath
    if ((Test-Path -LiteralPath $source) -and !(Test-Path -LiteralPath $backup)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $backup
    }
}
function Set-IniValue([string]$Section, [string]$Key, [string]$Value) {
    $sectionStart = -1
    for ($i = 0; $i -lt $script:iniLines.Count; $i++) {
        if ($script:iniLines[$i] -match ('^\s*\[' + [regex]::Escape($Section) + '\]\s*$')) {
            $sectionStart = $i
            break
        }
    }
    if ($sectionStart -lt 0) {
        $script:iniLines.Add("`r`n[$Section]")
        $script:iniLines.Add("$Key = $Value")
        return
    }
    $sectionEnd = $script:iniLines.Count
    for ($i = $sectionStart + 1; $i -lt $script:iniLines.Count; $i++) {
        if ($script:iniLines[$i] -match '^\s*\[') { $sectionEnd = $i; break }
        if ($script:iniLines[$i] -match ('^\s*' + [regex]::Escape($Key) + '\s*=')) {
            $script:iniLines[$i] = "$Key = $Value"
            return
        }
    }
    $script:iniLines.Insert($sectionEnd, "$Key = $Value")
}

if (!(Test-Path -LiteralPath $loader) -or !(Test-Path -LiteralPath $proxy)) {
    $cacheDirectory = Join-Path $repoDirectory '.cache'
    New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
    $archive = Join-Path $cacheDirectory "UE4SS_$($runtime.version).zip"
    if (!(Test-Path -LiteralPath $archive)) { Invoke-WebRequest -Uri $runtime.url -OutFile $archive }
    if ((Get-FileHash -LiteralPath $archive).Hash -ne $runtime.archiveSha256) {
        throw 'UE4SS archive checksum mismatch. Nothing from the archive was installed.'
    }
    $stagingDirectory = Join-Path $cacheDirectory $runtime.version
    Expand-Archive -LiteralPath $archive -DestinationPath $stagingDirectory -Force
    New-Item -ItemType Directory -Path $loaderDirectory -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $stagingDirectory 'dwmapi.dll') -Destination $proxy -Force
    Copy-Item -LiteralPath (Join-Path $stagingDirectory 'ue4ss\UE4SS.dll') -Destination $loader -Force
    Copy-Item -LiteralPath (Join-Path $stagingDirectory 'ue4ss\LICENSE') -Destination (Join-Path $loaderDirectory 'LICENSE') -Force
    foreach ($directory in @('Mods\shared', 'UE4SS_SDK_Backends')) {
        $destination = Join-Path $loaderDirectory $directory
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Get-ChildItem -LiteralPath (Join-Path $stagingDirectory "ue4ss\$directory") |
            Copy-Item -Destination $destination -Recurse -Force
    }
    $settings = Join-Path $loaderDirectory 'UE4SS-settings.ini'
    if (!(Test-Path -LiteralPath $settings)) {
        Copy-Item -LiteralPath (Join-Path $stagingDirectory 'ue4ss\UE4SS-settings.ini') -Destination $settings
    }
}

$payloadDirectory = Join-Path $repoDirectory 'mod'
foreach ($file in Get-ChildItem -LiteralPath $payloadDirectory -File -Recurse) {
    $relative = $file.FullName.Substring($payloadDirectory.Length + 1)
    Backup-File $relative
    $destination = Join-Path $binaryDirectory $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
}
$settings = Join-Path $loaderDirectory 'UE4SS-settings.ini'
Backup-File 'ue4ss\UE4SS-settings.ini'
$script:iniLines = [Collections.Generic.List[string]]::new()
if (Test-Path -LiteralPath $settings) {
    $script:iniLines.AddRange([string[]](Get-Content -LiteralPath $settings))
}
Set-IniValue 'General' 'EnableHotReloadSystem' '0'
Set-IniValue 'General' 'EnableAutoReloadingLuaMods' '0'
Set-IniValue 'General' 'bUseUObjectArrayCache' 'false'
Set-IniValue 'General' 'DefaultExecuteInGameThreadMethod' 'EngineTick'
Set-IniValue 'Debug' 'ConsoleEnabled' '0'
Set-IniValue 'Debug' 'GuiConsoleEnabled' '0'
Set-IniValue 'Debug' 'GuiConsoleVisible' '0'
Set-IniValue 'Hooks' 'HookEngineTick' '1'
[IO.File]::WriteAllLines($settings, $script:iniLines, [Text.UTF8Encoding]::new($false))

$modsFile = Join-Path $loaderDirectory 'Mods\mods.txt'
Backup-File 'ue4ss\Mods\mods.txt'
$mods = if (Test-Path -LiteralPath $modsFile) { [IO.File]::ReadAllText($modsFile) } else { '' }
$mods = [regex]::Replace($mods, '(?m)^\s*TextAutoToggle\s*:.*$', '')
[IO.File]::WriteAllText($modsFile, ($mods.TrimEnd() + "`r`nTextAutoToggle : 1`r`n"), [Text.UTF8Encoding]::new($false))
Write-Output 'TextAutoToggle installed. Launch the game through Steam. Xbox Y / keyboard A toggle automatic dialogue.'
