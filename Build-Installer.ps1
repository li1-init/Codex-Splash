param(
    [string]$CompilerPath,
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version = '1.0.0'
)

$ErrorActionPreference = 'Stop'
if (!$CompilerPath) {
    $compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($compiler) {
        $CompilerPath = $compiler.Source
    } else {
        foreach ($parent in @(${env:ProgramFiles(x86)}, $env:ProgramFiles, "$env:LOCALAPPDATA\Programs")) {
            if (!$parent) { continue }
            foreach ($edition in 'Inno Setup 7', 'Inno Setup 6') {
                $candidate = Join-Path $parent "$edition\ISCC.exe"
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $CompilerPath = $candidate
                    break
                }
            }
            if ($CompilerPath) { break }
        }
    }
}
if (!$CompilerPath -or !(Test-Path -LiteralPath $CompilerPath -PathType Leaf)) {
    throw 'Install Inno Setup 6 or 7, or pass the full ISCC.exe path with -CompilerPath.'
}

$recipe = Join-Path $PSScriptRoot 'installer\CodexSplash.iss'
& $CompilerPath "/DAppVersion=$Version" $recipe
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE." }
