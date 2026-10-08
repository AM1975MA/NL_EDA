# Build-only helper for AD26; never modifies Altium or ExtensionsRegistry.xml.
[CmdletBinding()]
param(
    [string]$AltiumInstallDir = "C:\Program Files\Altium\AD23",
    [ValidateSet('Debug','Release')]
    [string]$Configuration = 'Release'
)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot "EasyEDA-Loader\EasyEDA-Loader.csproj"
$altiumDll = Join-Path $AltiumInstallDir "System\Altium.SDK.dll"
$skinDll = Join-Path $AltiumInstallDir "Altium.Controls.Skins.dll"
$dxDir = Join-Path $AltiumInstallDir "System\DotNet\DevExpress.Wpf"
$expected = @(
    $project, $altiumDll, $skinDll,
    (Join-Path $dxDir 'DevExpress.Xpf.Core.v25.2.dll'),
    (Join-Path $dxDir 'DevExpress.Xpf.Grid.v25.2.dll')
)
foreach ($file in $expected) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing dependency: $file" }
}
$sdks = @(dotnet --list-sdks)
if ($LASTEXITCODE -ne 0 -or -not ($sdks | Where-Object { $_ -match '^8\.0\.' })) {
    throw ".NET 8 SDK required. Check: dotnet --list-sdks"
}
# Inspect embedded TFM metadata as a warning, not proof of hosting compatibility.
$txt = [System.Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($altiumDll))
$tfm = [regex]::Match($txt, '\.NETCoreApp,Version=v\d+\.\d+')
if ($tfm.Success) {
    Write-Host "Altium.SDK assembly declares: $($tfm.Value)"
    if ($tfm.Value -ne '.NETCoreApp,Version=v8.0') {
        Write-Warning "SDK TFM differs from candidate .NET 8. DO NOT DEPLOY without inspecting the AD26 host runtime."
    }
}
else {
    Write-Warning "SDK runtime target not detected; do not infer host compatibility."
}
Write-Host "Building (without installing) against: $AltiumInstallDir" -ForegroundColor Cyan
$env:NL_ALTIUM_HOME = $AltiumInstallDir
# Always compile afresh; fail on any new warnings rather than hiding them.
& dotnet build $project -c $Configuration -v minimal --no-incremental -warnaserror
if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
Write-Host "Build succeeded with zero warnings/errors; plugin NOT installed into Altium." -ForegroundColor Green
