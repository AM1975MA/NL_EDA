# NL_EDA — EasyEDALoader / Altium Designer 26

Development copy of [expired6978/EasyEDALoader](https://github.com/expired6978/EasyEDALoader) (upstream commit `1ade34da9c59ce53d27199452c4f7df9184d4789`). Original license is **GPL-3.0**; [LICENSE](LICENSE) and original notices are retained.

**Status: experimental, not yet compiled or tested on AD26.** This branch adapts project references to the user's Altium Designer **26.10.1.5** installation, which uses DevExpress **25.2**, and adds a build-only helper.

## Compiler warning fixes

- Added explicit assembly-level `[SupportedOSPlatform("windows10.0")]` because upstream disables `GenerateAssemblyInfo`; this properly communicates the Windows-only Altium host requirement and addresses `CA1416` without disabling the analyzer.
- Replaced the four `throw ex;` rethrows in `EasyedaApi.cs` with `throw;` to preserve exception stack traces (`CA2200`).
- User's first build completed with **0 errors and 48 warnings**. This fix still needs a fresh build on the user's Windows workstation to confirm **0 warnings**. Do not interpret absence of compiler errors as proof of plugin runtime compatibility. A successful compile alone does not establish the extension can be loaded by AD26.

## Build only (Windows, .NET 8 SDK, installed Altium 26)

```powershell
.\Build-AD26.ps1 -AltiumInstallDir "C:\Program Files\Altium\AD23"
```

This references `Altium.SDK.dll`, `Altium.SDK.Interfaces.dll`, `Altium.Controls*` and DevExpress assemblies **from the local Altium installation**. Proprietary DLLs are not included in this repository.

`All.ps1` and `Deploy.ps1` are **deliberately disabled** to prevent unintended registration into a wrong Altium instance. Read [docs/AD26.md](docs/AD26.md) before considering deployment.

## Function

The upstream plugin adds LCSC/EasyEDA parts directly to cumulative Altium `SchLib`/`PcbLib` libraries, including STEP 3D, without the KiCad Import Wizard. The original author reports known 3D alignment limitations and community members report AD26 startup/menu issues ([issue #5](https://github.com/expired6978/EasyEDALoader/issues/5), [issue #8](https://github.com/expired6978/EasyEDALoader/issues/8)). An independent AD26 smoke test is mandatory.

Source code is copied without binary screenshots; see [upstream Assets](https://github.com/expired6978/EasyEDALoader/tree/main/Assets) for original comparison images.

## Planned next changes

1. Resolve actual AD26 SDK/host TargetFramework compatibility, then any compiler/XAML errors.
2. Test component import into temporary libraries; verify pin/pad mapping and 3D transform.
3. Introduce robust LCSC-ID-based deduplication and quality/approval metadata.
4. Implement target-aware, rollback-safe Altium extension deployment after validation.

## Controlled AD26 deployment (not yet runtime tested)

Run the new `Manage-AD26.ps1` in the cloned/downloaded repository. **Default is read-only** (safe even with Altium running):

~~~powershell
.\Manage-AD26.ps1
~~~

Both install and uninstall are dry-runs without `-Apply`. To install, close Altium first and run the strict build in the same checkout, then explicitly run:

~~~powershell
.\Build-AD26.ps1
.\Manage-AD26.ps1 -Action Install -Apply
~~~

If Altium fails to start, close any remaining X2.exe process and run:

~~~powershell
.\Manage-AD26.ps1 -Action Uninstall -Apply
~~~

Backups are created under the current user's `Altium_EasyEDALoader_Backup` directory. The installer also places a copy of itself next to the backup registry XML. It checks the installed Altium 26.10.1.5 executable, the explicit Extensions registry path, known existing extension entries and exact input files. It will not auto-discover or overwrite another plugin folder. **The first actual AD26 installation remains untested: preflight first.**

## First install failure and safe simulation

The first attempted install reached the XML replacement call and failed with `Formato del percorso non valido`.
It used `File.Replace(temp, registry, null)`; automatic rollback was attempted but must be verified independently.
Check the active registry SHA256 matches the verified `before_install_20261008_152724_97098cae` backup and that no EasyEDA directory/registration remains.

The revised `Manage-AD26.ps1` supplies a non-null full backup pathname to `File.Replace`.
Before any further install, run `Manage-AD26.ps1 -Action SelfTest` in a new checkout.
The self-test clones the live registry into a disposable temporary directory, simulates installation/removal and verifies the live registry did not change.
The corrected script has not yet been run on the user workstation. It also verifies restored hashes and plugin folder state after a failed installation.
