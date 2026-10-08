# NL_EDA: controlled AD26 extension installer / uninstaller
# Default is read-only. Actual changes require -Action Install/Uninstall AND -Apply.
[CmdletBinding()]
param(
    [ValidateSet('Status','SelfTest','Install','Uninstall')][string]$Action = 'Status',
    [string]$ExtensionsRoot = 'C:\ProgramData\Altium\Altium Designer {8336EC4A-4F8B-4AB7-846D-48468FBB3C82}\Extensions',
    [string]$AltiumInstallDir = 'C:\Program Files\Altium\AD23',
    [string]$BuildOutput = '',
    [string]$BackupRoot = (Join-Path $env:USERPROFILE 'Altium_EasyEDALoader_Backup'),
    [switch]$Apply
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pluginId = 'EasyEDA-Loader'
$pluginGuid = '8035C261-E5FE-403B-A9B5-9ABFFB6E0EF5'
$pluginVersionGuid = '7042BC82-F870-462D-86AF-B158AC75C490'
$expectedVersion = '26.10.1.5'
$knownExtensions = @('KiCad Importer','ActiveRoute','ProjectHistory','NewmanCloud_BoMExtractor')
$pluginFiles = @('EasyEDA-Loader.dll','EasyEDA-Loader.Ins','EasyEDA-Loader.rcs',
    'EasyEDA-Loader.dll.config','EasyEDA-Loader.deps.json','Newtonsoft.Json.dll')

function VerifyHash([string]$Source, [string]$Copy) {
    if ((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $Copy -Algorithm SHA256).Hash) {
        throw "File checksum mismatch: $Source vs $Copy"
    }
}
function ReadRegistry([string]$File) {
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($File)
    if ($null -eq $doc.DocumentElement -or $doc.DocumentElement.Name -ne 'Extensions') {
        throw 'Unknown ExtensionsRegistry.xml format; refusing to write.'
    }
    return $doc
}
function PluginEntries([System.Xml.XmlDocument]$Doc) {
    return @($Doc.DocumentElement.SelectNodes("Item[@HRID='EasyEDA-Loader']"))
}
function SaveRegistry([System.Xml.XmlDocument]$Doc, [string]$File) {
    # Windows File.Replace needs explicit valid paths. Never pass a null backup path.
    # All three files reside on the same NTFS volume; an independent verified
    # snapshot also exists under Altium_EasyEDALoader_Backup for real changes.
    $target = [System.IO.Path]::GetFullPath($File)
    $folder = [System.IO.Path]::GetDirectoryName($target)
    $name = [System.IO.Path]::GetFileName($target)
    $token = [guid]::NewGuid().ToString('N')
    $temp = [System.IO.Path]::Combine($folder, "$name.NL_EDA_$token.tmp")
    $replaceBackup = [System.IO.Path]::Combine($folder, "$name.NL_EDA_$token.old")
    try {
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
        $settings.Indent = $false
        $writer = [System.Xml.XmlWriter]::Create($temp, $settings)
        try { $Doc.Save($writer) } finally { $writer.Close() }
        if (-not (Test-Path -LiteralPath $temp -PathType Leaf)) {
            throw "XML temporary file not created: $temp"
        }
        [System.IO.File]::Replace($temp, $target, $replaceBackup)
        # A Replace call that returns successfully must produce parseable XML.
        [void](ReadRegistry $target)
    }
    finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
        # Keep .old copy in place as an additional emergency recovery artifact.
        # Install/Uninstall already keep timestamped verified user-folder backups.
    }
}
function AddField($Doc, $Parent, [string]$Name, [string]$Value) {
    $child = $Doc.CreateElement($Name)
    $child.InnerText = $Value
    [void]$Parent.AppendChild($child)
}
function MakeEntry($Doc, [string]$Folder) {
    $item = $Doc.CreateElement('Item')
    $item.SetAttribute('HRID', $pluginId)
    $item.SetAttribute('Guid', $pluginGuid)
    $date = ([datetime]::Today - [datetime]'1899-12-30').TotalDays.ToString('F7',[cultureinfo]::InvariantCulture)
    $fields = [ordered]@{
        Path = $Folder; Status = '0'; VaultGuid = ''; CreatedBy = 'Altium, Inc.'
        CategoryGuid = '793A1F67-0B22-4E01-A5DE-3176A1E8C60D'
        CategoryName = ''; ReadMe = ''; Help = ''; Requirements = ''
        Title = $pluginId; ShortDescription = 'EasyEDA-Loader'
        LongDescription = 'Loads EasyEDA components into Altium Designer'
        SmallImage = ''; LargeImage = ''; Version = '1.0.0.0'
        VersionGuid = $pluginVersionGuid; ReleasedDate = $date
        ReleaseNotes = ''; DateInstalled = $date
    }
    foreach ($key in $fields.Keys) { AddField $Doc $item $key $fields[$key] }
    $platform = $Doc.CreateElement('PlatformVersions')
    foreach ($name in @('DXP','EDP','MaxDXP','MaxEDP')) {
        $el = $Doc.CreateElement($name)
        if ($name -like 'Max*') { $el.SetAttribute('BuildNumber','0.0.0.0') }
        else { $el.SetAttribute('BuildNumber','1.0.16.41') }
        [void]$platform.AppendChild($el)
    }
    [void]$item.AppendChild($platform)
    return $item
}
function RequireStopped {
    $processes = @(Get-Process -Name X2 -ErrorAction SilentlyContinue)
    if ($processes.Count -gt 0) {
        throw "Altium X2.exe is running (PID: $(($processes.Id) -join ', ')). Close Altium first."
    }
}
function MakeBackup([string]$Registry, [string]$Name) {
    $dir = Join-Path $BackupRoot ($Name + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $copy = Join-Path $dir 'ExtensionsRegistry.xml'
    Copy-Item -LiteralPath $Registry -Destination $copy -ErrorAction Stop
    VerifyHash $Registry $copy
    Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $dir 'Manage-AD26.ps1') -ErrorAction Stop
    return $dir
}

Write-Host ''
Write-Host '=== NL_EDA AD26 PREFLIGHT ===' -ForegroundColor Cyan
$registry = Join-Path $ExtensionsRoot 'ExtensionsRegistry.xml'
$destination = Join-Path $ExtensionsRoot $pluginId
$x2 = Join-Path $AltiumInstallDir 'X2.exe'
if (-not (Test-Path -LiteralPath $registry -PathType Leaf)) { throw "Registry missing: $registry" }
if (-not (Test-Path -LiteralPath $x2 -PathType Leaf)) { throw "Altium missing: $x2" }
$version = (Get-Item -LiteralPath $x2).VersionInfo.FileVersion
if ($version -ne $expectedVersion) { throw "Altium version mismatch: $version; expected $expectedVersion" }
$doc = ReadRegistry $registry
$nodes = @($doc.DocumentElement.SelectNodes('Item'))
$hrids = @($nodes | ForEach-Object { $_.GetAttribute('HRID') })
$missing = @($knownExtensions | Where-Object { $_ -notin $hrids })
if ($missing.Count -gt 0) { throw "Unrecognized Extensions registry; missing: $($missing -join ', ')" }
$registered = @(PluginEntries $doc)
if ($registered.Count -gt 1) { throw 'Multiple EasyEDA registry entries: manual intervention required.' }

Write-Host "Altium version: $version"
Write-Host "Registry: $registry"
Write-Host "Extensions registered: $($nodes.Count)"
Write-Host "EasyEDA registered: $($registered.Count -eq 1)"
Write-Host "EasyEDA directory exists: $(Test-Path -LiteralPath $destination)"
Write-Host "Altium running: $(@(Get-Process X2 -ErrorAction SilentlyContinue).Count -gt 0)"
Write-Host "Backup root: $BackupRoot"

if ($Action -eq 'Status') {
    Write-Host 'STATUS COMPLETE - READ ONLY' -ForegroundColor Green
    return
}
if ($Action -eq 'SelfTest') {
    $beforeHash = (Get-FileHash -LiteralPath $registry -Algorithm SHA256).Hash
    # Exercise the exact XML save/replace/restore algorithm on a disposable copy.
    # The production Extensions registry and plugin folder stay untouched.
    $fixtureDir = Join-Path ([IO.Path]::GetTempPath()) ("NL_EDA_RegistryTest_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null
    try {
        $fixturePath = Join-Path $fixtureDir 'ExtensionsRegistry.xml'
        Copy-Item -LiteralPath $registry -Destination $fixturePath -ErrorAction Stop
        VerifyHash $registry $fixturePath
        $fixtureXml = ReadRegistry $fixturePath
        if (@(PluginEntries $fixtureXml).Count -ne 0) {
            throw "Self-test requires absent EasyEDA registration in source registry."
        }
        [void]$fixtureXml.DocumentElement.AppendChild((MakeEntry $fixtureXml (Join-Path $fixtureDir 'EasyEDA-Loader')))
        SaveRegistry $fixtureXml $fixturePath
        $installedXml = ReadRegistry $fixturePath
        if (@(PluginEntries $installedXml).Count -ne 1) {
            throw 'Self-test failed: simulated registry install entry missing.'
        }
        [void]$installedXml.DocumentElement.RemoveChild(@(PluginEntries $installedXml)[0])
        SaveRegistry $installedXml $fixturePath
        if (@(PluginEntries (ReadRegistry $fixturePath)).Count -ne 0) {
            throw 'Self-test failed: simulated uninstall entry still present.'
        }
        # The real registry is compared with the original SHA256 taken before simulation.
        $afterHash = (Get-FileHash -LiteralPath $registry -Algorithm SHA256).Hash
        if ($afterHash -ne $beforeHash) {
            throw 'Self-test safety failure: real registry checksum changed.'
        }
        Write-Host 'SELFTEST PASS: install/uninstall XML changes on temporary copy only' -ForegroundColor Green
    }
    finally {
        if (Test-Path -LiteralPath $fixtureDir) {
            Remove-Item -LiteralPath $fixtureDir -Recurse -Force
        }
    }
    return
}
if (-not $Apply) {
    Write-Host "DRY RUN ONLY - pass -Apply to actually $Action" -ForegroundColor Yellow
    return
}
RequireStopped

if ($Action -eq 'Install') {
    if ($registered.Count -gt 0 -or (Test-Path -LiteralPath $destination)) {
        throw 'EasyEDA already installed or folder already exists; refusing to overwrite.'
    }
    if (-not $BuildOutput) { $BuildOutput = Join-Path $PSScriptRoot 'EasyEDA-Loader\bin\Release' }
    foreach ($file in $pluginFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $BuildOutput $file) -PathType Leaf)) {
            throw "Missing build file '$file' in '$BuildOutput'. No changes made."
        }
    }
    $backup = MakeBackup $registry 'before_install'
    Write-Host "Verified registry backup: $backup"
    $created = $false
    try {
        New-Item -ItemType Directory -Path $destination -ErrorAction Stop | Out-Null
        $created = $true
        foreach ($file in $pluginFiles) {
            $from = Join-Path $BuildOutput $file
            $to = Join-Path $destination $file
            Copy-Item -LiteralPath $from -Destination $to -ErrorAction Stop
            VerifyHash $from $to
        }
        $entry = MakeEntry $doc $destination
        [void]$doc.DocumentElement.AppendChild($entry)
        SaveRegistry $doc $registry
        if (@(PluginEntries (ReadRegistry $registry)).Count -ne 1) {
            throw 'Registry post-install validation failed.'
        }
        @(
            'NL_EDA recovery instructions:',
            'Close Altium completely.',
            'Run: .\Manage-AD26.ps1 -Action Uninstall -Apply',
            'If that fails, restore ExtensionsRegistry.xml from this folder to the original registry path.',
            'Then remove ONLY the EasyEDA-Loader plugin directory.',
            "Original registry: $registry",
            "Plugin directory: $destination"
        ) | Set-Content -LiteralPath (Join-Path $backup 'RECOVERY.txt') -Encoding UTF8
        Write-Host "INSTALL COMPLETE - Recovery backup: $backup" -ForegroundColor Green
    }
    catch {
        $reason = $_.Exception.Message
        Write-Warning "Install failed ($reason). Attempting rollback."
        $previous = Join-Path $backup 'ExtensionsRegistry.xml'
        $rollbackErrors = @()
        try {
            Copy-Item -LiteralPath $previous -Destination $registry -Force -ErrorAction Stop
            VerifyHash $previous $registry
        }
        catch { $rollbackErrors += "Registry recovery: $($_.Exception.Message)" }
        try {
            if ($created -and (Test-Path -LiteralPath $destination)) {
                Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction Stop
            }
            if (Test-Path -LiteralPath $destination) {
                throw 'EasyEDA plugin directory still present.'
            }
        }
        catch { $rollbackErrors += "Plugin directory recovery: $($_.Exception.Message)" }
        if ($rollbackErrors.Count -eq 0) {
            throw "Installation failed, ROLLBACK VERIFIED: $reason"
        }
        throw "Installation failed; ROLLBACK INCOMPLETE: $($rollbackErrors -join ' | '). Original: $reason"
    }
}
elseif ($Action -eq 'Uninstall') {
    if ($registered.Count -eq 0 -and -not (Test-Path -LiteralPath $destination)) {
        Write-Host 'Nothing installed.' -ForegroundColor Green
        return
    }
    if ($registered.Count -eq 1) {
        $pathNode = $registered[0].SelectSingleNode('Path')
        if ($null -eq $pathNode -or $pathNode.InnerText -ne $destination) {
            throw 'EasyEDA registered path is unexpected. Refusing to remove.'
        }
    }
    if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) {
        throw "Recovery backups not found: $BackupRoot"
    }
    $backup = MakeBackup $registry 'before_uninstall'
    if (Test-Path -LiteralPath $destination -PathType Container) {
        Copy-Item -LiteralPath $destination -Destination (Join-Path $backup 'EasyEDA-Loader') -Recurse -ErrorAction Stop
    }
    if ($registered.Count -eq 1) {
        [void]$doc.DocumentElement.RemoveChild($registered[0])
        SaveRegistry $doc $registry
    }
    if (Test-Path -LiteralPath $destination -PathType Container) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    Write-Host "UNINSTALL COMPLETE - Recovery backup: $backup" -ForegroundColor Green
}
