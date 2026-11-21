$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'Launch.ps1'
$video = Join-Path $PSScriptRoot '.Welcome Jay.overlay.mp4'
$portal = Join-Path $PSScriptRoot 'portal.json'
foreach ($file in @($launcher, $video, $portal)) {
    if (!(Test-Path -LiteralPath $file)) { throw "Missing launch dependency: $file" }
}

$desktop = [Environment]::GetFolderPath('DesktopDirectory')
$linkPath = Join-Path $desktop 'ChatGPT - Welcome Jay.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($linkPath)
$shortcut.TargetPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$shortcut.Arguments = '-NoProfile -Sta -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $launcher + '"'
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.WindowStyle = 7
$shortcut.Description = 'Open ChatGPT with the Welcome Jay cold-start animation'

$app = Get-AppxPackage -Name OpenAI.Codex | Select-Object -First 1
if ($app) { $shortcut.IconLocation = (Join-Path $app.InstallLocation 'app\ChatGPT.exe') + ',0' }
$shortcut.Save()
Get-Item -LiteralPath $linkPath | Select-Object Name, FullName
