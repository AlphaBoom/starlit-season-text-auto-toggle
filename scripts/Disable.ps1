[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$GameDirectory)
$ErrorActionPreference = 'Stop'
$gameRoot = (Resolve-Path -LiteralPath $GameDirectory).Path
$modsDirectory = Join-Path $gameRoot 'StarlitSeason\Binaries\Win64\ue4ss\Mods'
if (!(Test-Path -LiteralPath $modsDirectory)) { throw 'UE4SS Mods directory was not found.' }
if (Get-Process -Name 'StarlitSeason-Win64-Shipping' -ErrorAction SilentlyContinue) {
    throw 'Close the game before disabling the mod.'
}
$modsFile = Join-Path $modsDirectory 'mods.txt'
$mods = if (Test-Path -LiteralPath $modsFile) { [IO.File]::ReadAllText($modsFile) } else { '' }
$mods = [regex]::Replace($mods, '(?m)^\s*TextAutoToggle\s*:.*$', '')
[IO.File]::WriteAllText($modsFile, ($mods.TrimEnd() + "`r`nTextAutoToggle : 0`r`n"), [Text.UTF8Encoding]::new($false))
$enabledFile = Join-Path $modsDirectory 'TextAutoToggle\enabled.txt'
if (Test-Path -LiteralPath $enabledFile) { Remove-Item -LiteralPath $enabledFile }
Write-Output 'TextAutoToggle disabled. Its source files and the shared UE4SS loader were retained.'
