# App Attach accelerators

These tools help a small team move from zero App Attach experience to the first applications delivered through Azure Virtual Desktop. They are written for a pooled Azure Virtual Desktop North Star that keeps the base image lean, uses App Attach above the image, and starts with simple packages before scaling the process.

The scripts are generic and use Contoso examples only. They do not contain tenant IDs, subscription IDs or customer-specific values.

## Fast track workflow

1. **Inventory the App-V backlog.** Run [Get-AppVPackageInventory.ps1](./Get-AppVPackageInventory.ps1) against the package share. Export CSV for triage and JSON for automation.
2. **Triage into waves.** Start with packages that have clear owners, simple integration points and no dynamic configuration scripts. Put packages with COM, services, shell extensions, scripts or complex user configuration into a later test wave.
3. **Prove App Attach with App-V packages as they are.** Microsoft Learn says App Attach supports App-V packages and that App-V app attach can use existing App-V packages in Azure Virtual Desktop without running your own App-V server. Use that as the bridge, not as the destination.
4. **Convert where needed.** Use the MSIX Packaging Tool for candidates that should become MSIX. Learn documents App-V as an input for the MSIX Packaging Tool and notes that the tool supports App-V 5.1. Use [New-MsixConversionTemplate.ps1](./New-MsixConversionTemplate.ps1) to create starter command-line conversion templates from the inventory output.
5. **Create images for MSIX and Appx packages.** Use [New-AppAttachImage.ps1](./New-AppAttachImage.ps1) with MSIXMGR. It defaults to CimFS because Microsoft Learn recommends CimFS for Windows 11 session hosts. Use VHDX only when you need a single image file.
6. **Check the file share.** Use [Test-AppAttachShare.ps1](./Test-AppAttachShare.ps1) to run read-only checks against the Azure Files share, Microsoft Entra Kerberos setting and the documented service principal role assignments.
7. **Onboard the first wave.** Use [Add-AppAttachApplication.ps1](./Add-AppAttachApplication.ps1) to import package metadata, create App Attach packages, assign host pools and assign Microsoft Entra groups. Run with `-WhatIf` first.
8. **Test with real users.** Validate sign-in, first launch, second launch, file associations, URL protocols, user settings, add-ins, update behaviour and sign-in impact in a representative host pool.

## Prerequisites

- PowerShell 7.2 or later.
- For Azure onboarding, Az.DesktopVirtualization version 4.2.1 or later, because Microsoft Learn says that version contains the App Attach cmdlets.
- Az.Resources for `New-AzRoleAssignment` and `Get-AzRoleAssignment`.
- Az.Storage for the read-only share checker.
- Desktop Virtualization Contributor on the resource group as a minimum to add App Attach packages. To assign users or groups, the operator also needs `Microsoft.Authorization/roleAssignments/write` on the application scope, such as through Owner or User Access Administrator.
- An SMB file share in the same Azure region as the session hosts, with session host computer accounts able to read the packages.
- For Microsoft Entra joined session hosts using Azure Files, Microsoft Learn requires the **Reader and Data Access** role for both the **Azure Virtual Desktop** and **Azure Virtual Desktop ARM Provider** service principals. The storage account must be in the same subscription as the session host VMs.
- MSIXMGR to create MSIX or Appx images.
- The MSIX Packaging Tool for conversion work.
- A trusted code signing process for MSIX and Appx packages. Microsoft Learn says all MSIX and Appx packages include a certificate and the chain must be trusted on session hosts.
- The Microsoft Learn App Attach example passes `-Location` to `Update-AzWvdAppAttachPackage`, but Az.DesktopVirtualization 6.0.0 does not accept that parameter on update, so [Add-AppAttachApplication.ps1](./Add-AppAttachApplication.ps1) only adds it when the installed cmdlet supports it.

## Scripts

### Get-AppVPackageInventory.ps1

Offline inventory for `.appv` files. It opens each package as a zip archive, reads `AppxManifest.xml` without relying on XML namespace prefixes, and reports:

- package name, version, publisher, architecture, package ID, version ID and size
- applications in the package
- integration points such as shortcuts, file type associations, URL protocols, COM, services, shell extensions, fonts, environment variables, capabilities and dependency elements
- other manifest elements for triage
- whether `<name>_DeploymentConfig.xml` and `<name>_UserConfig.xml` sit beside the package
- whether those dynamic configuration files contain script elements

Examples:

```powershell
.\Get-AppVPackageInventory.ps1 -Path \\contoso.file.core.windows.net\packages -Recurse
```

```powershell
.\Get-AppVPackageInventory.ps1 -Path C:\Packages -Recurse -CsvPath C:\Temp\appv-inventory.csv -JsonPath C:\Temp\appv-inventory.json
```

### Add-AppAttachApplication.ps1

Creates App Attach package resources and assigns them. It follows the Microsoft Learn PowerShell flow:

1. `Import-AzWvdAppAttachPackageInfo`
2. `New-AzWvdAppAttachPackage`
3. `Update-AzWvdAppAttachPackage` with `HostPoolReference`
4. `New-AzRoleAssignment` with the **Desktop Virtualization User** role

Use only documented App Attach inputs: `.cim`, `.vhdx`, `.vhd` and `.appv`. Learn supports VHD but does not recommend it, so use CimFS or VHDX for new MSIX and Appx images.

Example:

```powershell
.\Add-AppAttachApplication.ps1 `
  -ResourceGroupName rg-avd-apps `
  -Location australiaeast `
  -HostPoolName hp-contoso-pooled `
  -PackagePath \\contoso.file.core.windows.net\apps\ContosoApp.cim `
  -Name contoso-app `
  -DisplayName "Contoso App" `
  -HostPoolResourceId /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/hp-contoso-pooled `
  -GroupObjectId 11111111-1111-1111-1111-111111111111 `
  -WhatIf
```

Bulk CSV columns:

```csv
ResourceGroupName,Location,HostPoolName,PackagePath,Name,DisplayName,SubscriptionId,PackageFullName,HostPoolResourceId,GroupObjectId
rg-avd-apps,australiaeast,hp-contoso-pooled,\\contoso.file.core.windows.net\apps\ContosoApp.cim,contoso-app,Contoso App,,,/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/hp-contoso-pooled,11111111-1111-1111-1111-111111111111
```

Multiple host pool or group IDs in CSV cells use semicolons.

### New-AppAttachImage.ps1

Creates App Attach images from `.msix`, `.msixbundle`, `.appx` or `.appxbundle` packages by running the documented MSIXMGR command line:

```cmd
msixmgr.exe -Unpack -packagePath "C:\msix\myapp.msix" -destination "C:\msix\myapp\myapp.cim" -applyACLs -create -fileType cim -rootDirectory apps
```

Examples:

```powershell
.\New-AppAttachImage.ps1 -PackagePath C:\Packages\*.msix -OutputDirectory C:\AppAttachImages -WhatIf
```

```powershell
.\New-AppAttachImage.ps1 -PackagePath C:\Packages\Contoso.msix -OutputDirectory C:\AppAttachImages -ImageType VHDX -MsixMgrPath C:\Tools\msixmgr.exe -PassThru
```

### New-MsixConversionTemplate.ps1

Creates starter MSIX Packaging Tool command-line conversion templates from App-V inventory JSON or from an installer CSV. Learn documents command-line conversion with a template file and documents App-V, MSI and EXE as MSIX Packaging Tool inputs. The generated templates deliberately omit signing information so that people choose the correct certificate and approval path.

Example:

```powershell
.\New-MsixConversionTemplate.ps1 `
  -InventoryJsonPath C:\Temp\appv-inventory.json `
  -OutputDirectory C:\Temp\templates `
  -PackageOutputDirectory C:\Temp\msix `
  -PublisherName "CN=Contoso" `
  -PublisherDisplayName "Contoso"
```

Installer CSV columns:

```csv
ApplicationName,InstallerPath,InstallerArguments,InstallLocation,PackageName,PackageDisplayName,PublisherName,PublisherDisplayName,Version,PackageOutputPath,TemplateOutputPath
Contoso Claims Viewer,\\contoso\source\ClaimsViewer\setup.msi,"/qn /norestart",C:\Program Files\Contoso Claims Viewer,Contoso.ClaimsViewer,Contoso Claims Viewer,CN=Contoso,Contoso,1.0.0.0,,
```

Example:

```powershell
.\New-MsixConversionTemplate.ps1 `
  -InstallerCsvPath C:\Temp\source-installers.csv `
  -OutputDirectory C:\Temp\templates `
  -PackageOutputDirectory C:\Temp\msix `
  -PublisherName "CN=Contoso" `
  -PublisherDisplayName "Contoso"
```

### Test-AppAttachShare.ps1

Runs read-only checks against an Azure Files share:

- storage account exists
- file share exists
- Microsoft Entra Kerberos flag is enabled on the storage account
- **Reader and Data Access** role assignment exists for the **Azure Virtual Desktop** and **Azure Virtual Desktop ARM Provider** service principals at the storage account scope

Example:

```powershell
.\Test-AppAttachShare.ps1 -ResourceGroupName rg-avd-storage -StorageAccountName contosoapps -ShareName appattach
```

## From golden image to App Attach

Many teams start with a golden image that contains every application, often built by a Configuration Manager task sequence. Applications cannot be literally extracted from an installed image. The realistic path is to inventory what is installed, triage each application, find the source installer or package, then repackage from source in controlled waves.

### Workflow

1. **Get access to the image safely.** Either deploy a VM from the Azure Compute Gallery image version and run [Get-ImageApplicationInventory.ps1](./Get-ImageApplicationInventory.ps1) in online mode, or export the image version to a managed disk, attach it to a utility VM and run the script in offline mode against the mounted Windows folder. Microsoft Learn documents creating a VM from a generalized image version and exporting an image version to a managed disk.
2. **Inventory the image.** Online mode reports Uninstall registry entries, provisioned Appx and MSIX packages, App-V client packages if the client cmdlets are present, and non-Microsoft services and drivers. Offline mode loads the mounted image SOFTWARE hive with `reg load`, reads Uninstall entries, calls `Get-AppxProvisionedPackage -Path`, reports non-Microsoft driver files where visible, and unloads the hive in a finally block with `reg unload`.
3. **Triage with editable rules.** Run [Invoke-ApplicationTriage.ps1](./Invoke-ApplicationTriage.ps1) with [triage-rules.json](./triage-rules.json). The rules are editable regular expressions over name, publisher, path and source type. Output categories are `KeepInBaseImage`, `AppAttachAppV`, `AppAttachMsix`, `ReviewDriversOrServices`, `LegacyPool` and `Retire`.
4. **Find the source.** Use Configuration Manager to identify application deployment types, installation files, detection methods, requirements and command lines where they exist. Microsoft Learn says a Configuration Manager application has one or more deployment types, and deployment types include the installation files and information required to install software.
5. **Generate conversion templates.** Put source installer paths and silent command lines into an installer CSV, then run [New-MsixConversionTemplate.ps1](./New-MsixConversionTemplate.ps1) in `-InstallerCsvPath` mode.
6. **Package, sign and image.** Use the MSIX Packaging Tool to convert suitable packages, sign them with a certificate trusted on session hosts, then use [New-AppAttachImage.ps1](./New-AppAttachImage.ps1) to create CimFS or VHDX images.
7. **Onboard and test.** Add packages with [Add-AppAttachApplication.ps1](./Add-AppAttachApplication.ps1), assign them to host pools and groups, then test with real users before removing the application from the base image.

### Get-ImageApplicationInventory.ps1

Examples:

```powershell
.\Get-ImageApplicationInventory.ps1 -Mode Online -CsvPath C:\Temp\image-apps.csv -JsonPath C:\Temp\image-apps.json
```

```powershell
.\Get-ImageApplicationInventory.ps1 -Mode Offline -WindowsPath F:\Windows -JsonPath C:\Temp\offline-image-apps.json
```

Offline mode requires an elevated PowerShell session because `reg load` loads the mounted image SOFTWARE hive under `HKLM`. The script reads the hive and unloads it in a finally block.

### Invoke-ApplicationTriage.ps1

Examples:

```powershell
.\Invoke-ApplicationTriage.ps1 -InputPath C:\Temp\image-apps.json -RulesPath .\triage-rules.json -CsvPath C:\Temp\triage.csv
```

The default rules are a starting point:

- `KeepInBaseImage`: runtimes, redistributables, security tooling, management agents and Microsoft 365 Apps.
- `AppAttachAppV`: applications where an App-V package already exists.
- `AppAttachMsix`: normal applications that should be repackaged from source.
- `ReviewDriversOrServices`: applications with drivers, services or elevation patterns that need packaging review.
- `LegacyPool`: set by a person when an application needs a separate host pool, such as a hybrid joined pool.
- `Retire`: set by a person when the application should not move forward.

Microsoft Learn's MSIX preparation guidance is clear that some applications need remediation or are poor packaging candidates, including applications that always require elevation, require user Windows services, depend on drivers or make assumptions about writing to install locations. Treat `ReviewDriversOrServices` as a testing and design queue, not as an automatic rejection.

### What stays in the base image

Keep the platform in the image: Windows, servicing baseline, Microsoft 365 Apps where that is the organisation's standard, security agents, management agents, runtimes and redistributables that many packages depend on. Move business applications above the image where possible, first with existing App-V packages where appropriate, then with MSIX or Appx images for repackaged applications.

### Honest limits

Some applications will not package cleanly. Drivers, shell-level integrations, services, mandatory elevation, licensing components and machine-bound add-ins can force a package into `ReviewDriversOrServices`, `KeepInBaseImage` or `LegacyPool`. Every package needs owner testing, signing approval, rollback planning and production wave approval.

## Where AI assistants help

AI assistants such as GitHub Copilot help most with repetitive packaging work, not with approval decisions. Useful tasks include summarising the inventory CSV into waves, highlighting packages with script-heavy dynamic configuration files, drafting MSIX conversion templates, explaining MSIXMGR or MSIX Packaging Tool errors, and generating first-pass test scripts from package metadata. Keep human ownership for package signing, risk acceptance, application-owner testing, production wave approval, security exceptions, rollback decisions and final user communications.

## Microsoft Learn references

- [App Attach in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)
- [Add and manage App Attach applications in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup)
- [Create an MSIX image to use with App Attach in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image)
- [MSIXMGR tool parameters](https://learn.microsoft.com/windows/msix/package/msixmgr-tool)
- [How to generate a template file for command line conversions](https://learn.microsoft.com/windows/msix/packaging-tool/generate-template-file)
- [Create an MSIX package from any desktop installer](https://learn.microsoft.com/windows/msix/packaging-tool/create-app-package)
- [Prepare to package a desktop application](https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare)
- [Known issues and troubleshooting tips for the MSIX Packaging Tool](https://learn.microsoft.com/windows/msix/packaging-tool/tool-known-issues)
- [App-V in Windows support policy](https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy)
- [Assign Azure RBAC roles or Microsoft Entra roles to a service principal](https://learn.microsoft.com/azure/virtual-desktop/service-principal-assign-roles)
- [Enable Microsoft Entra Kerberos authentication for Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable)
- [Windows Installer Properties for the Uninstall Registry Key](https://learn.microsoft.com/windows/win32/msi/uninstall-registry-key)
- [reg load](https://learn.microsoft.com/windows-server/administration/windows-commands/reg-load)
- [reg unload](https://learn.microsoft.com/windows-server/administration/windows-commands/reg-unload)
- [Get-AppxProvisionedPackage](https://learn.microsoft.com/powershell/module/dism/get-appxprovisionedpackage)
- [Create a VM from a generalized image version](https://learn.microsoft.com/azure/virtual-machines/vm-generalized-image-version)
- [Export an image version to a managed disk](https://learn.microsoft.com/azure/virtual-machines/managed-disk-from-image-version)
- [Create applications in Configuration Manager](https://learn.microsoft.com/intune/configmgr/apps/deploy-use/create-applications)
