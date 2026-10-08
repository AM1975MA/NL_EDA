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
