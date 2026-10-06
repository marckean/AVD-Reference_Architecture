---
name: app-attach-onboarding
description: Run the App Attach toolkit in tools/app-attach to convert, image and onboard applications for Azure Virtual Desktop - MSIX Packaging Tool conversion templates, MSIXMGR CimFS images, App Attach packages, host pool and group assignments, and file share readiness checks. Use when someone wants to onboard applications to App Attach, build images, generate conversion templates, or troubleshoot an App Attach onboarding error.
argument-hint: "[what you want to onboard, convert or check]"
---

# Onboard applications to App Attach

Help the user run the scripts in [tools/app-attach](../../../tools/app-attach/README.md) safely, in the right order. Always propose `-WhatIf` first for anything that changes Azure.

## The scripts and their parameters

| Script | Use it to | Key parameters |
| --- | --- | --- |
| `Test-AppAttachShare.ps1` | Check, read-only, that an Azure Files share is ready, including the roles Microsoft Entra joined hosts need | `-ResourceGroupName`, `-StorageAccountName`, `-ShareName`, `-SubscriptionId` |
| `New-MsixConversionTemplate.ps1` | Write MSIX Packaging Tool conversion templates in bulk | From an App-V inventory: `-InventoryJsonPath`. From source installers: `-InstallerCsvPath`. Both need `-OutputDirectory`, `-PackageOutputDirectory`, `-PublisherName` and `-PublisherDisplayName`; `-Version` is optional |
| `New-AppAttachImage.ps1` | Turn MSIX or Appx packages into App Attach images with MSIXMGR | `-PackagePath`, `-OutputDirectory`, `-ImageType` (CimFS by default), `-MsixMgrPath` |
| `Add-AppAttachApplication.ps1` | Create App Attach packages and assign host pools and groups | Single: `-ResourceGroupName`, `-Location`, `-HostPoolName`, `-PackagePath`, `-Name`, plus optional `-DisplayName`, `-HostPoolResourceId`, `-GroupObjectId`. Bulk: `-CsvPath`. Also `-FailHealthCheckOnStagingFailure` (`Unhealthy`, `NeedsAssistance` or `DoNotFail`) |

## Order of work

1. **Share ready.** Run `Test-AppAttachShare.ps1`. For Microsoft Entra joined session hosts on Azure Files, Learn requires the **Reader and Data Access** role for the **Azure Virtual Desktop** and **Azure Virtual Desktop ARM Provider** service principals ([Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup)).
2. **Packages ready.** App-V packages can be used as they are. MSIX and Appx packages must be signed with a certificate the session hosts trust, then turned into images. Prefer CimFS, which Learn recommends for Windows 11 ([Create an MSIX image](https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image)).
3. **Onboard with -WhatIf.** Run `Add-AppAttachApplication.ps1 ... -WhatIf` and check what it would do. Then run it for real against a test host pool and a test group.
4. **Test with real users.** Check first launch, second launch, file associations, add-ins and sign-in time.

## Troubleshooting checklist

- **Package won't stage:** check that the package certificate is trusted on the session hosts, the share path is correct, and the session hosts can reach the share.
- **Works on hybrid joined hosts but not Microsoft Entra joined ones:** check the two service principal role assignments on the storage account.
- **Users don't see the application:** check the group assignment on the App Attach package and the host pool assignment.
- **The module rejects a parameter:** the Learn example for `Update-AzWvdAppAttachPackage` was written for Az.DesktopVirtualization 4.2.1. Check the installed module with `Get-Command <cmdlet> -Syntax`.

## Rules

- Verify cmdlet names and parameters against Microsoft Learn or the installed module. Don't guess.
- Never change production assignments without `-WhatIf` first and a person's approval.
- People own code signing, testing and approval.
