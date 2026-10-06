---
title: App Attach fast track
description: How a small team with no App Attach experience gets its first applications delivered by App Attach quickly - from an App-V share or from a golden image - using the toolkit in the repository and an AI assistant.
---

# App Attach fast track

!!! abstract "At a glance"
    - This page is for a team that has never used App Attach, has a backlog of App-V packages or a golden image with every application installed, and has very few people.
    - The fast track has six stages: get the platform ready, inventory, triage, prove App Attach with packages that need no conversion, convert the rest from source, then run it as a service. Every stage has a script in the [toolkit](https://github.com/marckean/AVD-Reference_Architecture/tree/main/tools/app-attach).
    - Existing App-V packages are the quickest win, because App Attach can use them as they are. MSIX conversion comes after the platform is proven, not before.
    - Applications can't be lifted out of an installed golden image. The reliable route is to inventory the image, then rebuild each application from its source installer.
    - An AI assistant speeds up the reading, drafting and explaining. People still own testing, code signing and approval.

## Who this is for

Picture a platform team of two or three people. Their virtual desktops run on a golden image that has had applications added to it for years. Some applications are already sequenced as App-V packages, many more are installed straight into the image, and a few are so old that nobody wants to touch them. The team has never used App Attach and has no spare capacity for a long packaging project.

That's a common starting point, and it's workable. App Attach lets you keep applications out of the image: Microsoft Learn says that with App Attach, *"Applications aren't installed locally on session hosts or images, making it easier to create custom images for your session hosts, and reducing operational overhead and costs for your organization"* ([App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)). The trick is to get the first applications working quickly, prove the platform, then scale the process.

## The fast track

| Stage | What you do | Toolkit | Done when |
| --- | --- | --- | --- |
| **0. Platform ready** | Create the App Attach file share and grant access. For Microsoft Entra joined session hosts on Azure Files, Learn requires the **Reader and Data Access** role for the **Azure Virtual Desktop** and **Azure Virtual Desktop ARM Provider** service principals ([Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup)) | [Test-AppAttachShare.ps1](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/Test-AppAttachShare.ps1) checks the share and the role assignments, read-only. The [Deploy to Azure](deploy-to-azure.md) pilot creates the share for you | The share checker passes |
| **1. Inventory** | List every application: App-V packages on the package share, and everything installed in the golden image | [Get-AppVPackageInventory.ps1](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/Get-AppVPackageInventory.ps1) reads `.appv` files without the App-V client. [Get-ImageApplicationInventory.ps1](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/Get-ImageApplicationInventory.ps1) reads a golden image, online or offline | A CSV of every application, with integration points and dependencies |
| **2. Triage** | Sort every application into a delivery route, and give each one an owner | [Invoke-ApplicationTriage.ps1](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/Invoke-ApplicationTriage.ps1) applies editable rules from [triage-rules.json](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/triage-rules.json) | Each application has a route and an owner |
| **3. First wave** | Add App-V packages that need no conversion to App Attach, assign them to a test group, and test with real users | [Add-AppAttachApplication.ps1](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/Add-AppAttachApplication.ps1), with `-WhatIf` first. It also takes a CSV for bulk onboarding | Assigned applications appear at sign-in and work for the test group |
| **4. Convert from source** | Repackage the next waves as MSIX on a clean packaging machine, sign them, and turn them into disk images | [New-MsixConversionTemplate.ps1](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/New-MsixConversionTemplate.ps1) writes MSIX Packaging Tool templates in bulk. [New-AppAttachImage.ps1](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/New-AppAttachImage.ps1) builds the images with MSIXMGR | Each wave is signed, imaged, onboarded and signed off by its application owner |
| **5. Run it** | Update applications with new versions, retire old ones, and keep the image lean | The same scripts, run from a pipeline | Adding or updating an application never needs a new image |

### Why App-V packages go first

App Attach accepts App-V packages directly. The App-V support policy says *"App-V app attach allows you to use your App-V packages with AVD without needing to run your own server"* ([App-V support policy](https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy)). So the first wave proves the file share, the permissions, the assignments and the user experience without waiting for any repackaging. App-V is a bridge, not the destination; the [From App-V to App Attach](../app-attach/from-app-v.md) page explains why.

### Converting from source

For applications that should become MSIX, the MSIX Packaging Tool captures an installation on a clean machine and produces a package. It can run unattended from a conversion template ([Generate a command line template](https://learn.microsoft.com/windows/msix/packaging-tool/generate-template-file)), which is what lets a small team convert in bulk. Two rules matter from day one:

- **Every package must be signed with a certificate the session hosts trust.** Learn says all MSIX and Appx packages include a certificate, and you're responsible for making sure it's trusted in your environment ([App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)). If you don't have a code signing process yet, it's on the critical path.
- **Use CimFS images.** Learn says: *"We recommend using CIM for best performance, particularly with Windows 11, as it consumes less CPU and memory, with improved mounting and unmounting times"* ([Create an MSIX image](https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image)).

## Starting from a golden image

You can't extract an installed application from a golden image and turn it into an App Attach package. An installed application is spread across folders, registry keys, services and shortcuts, and nothing records exactly which pieces belong to it. The dependable route is to work out what's in the image, then rebuild each application from its source.

1. **Inventory the image without changing it.** Either deploy a virtual machine from the image version in Azure Compute Gallery and run [Get-ImageApplicationInventory.ps1](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/Get-ImageApplicationInventory.ps1) inside it, or create a managed disk from the image version, attach it to a utility machine and run the script offline against the mounted disk ([Create a managed disk from an image version](https://learn.microsoft.com/azure/virtual-machines/managed-disk-from-image-version)). It reads the Windows Installer uninstall entries for 64-bit and 32-bit applications ([Uninstall registry key](https://learn.microsoft.com/windows/win32/msi/uninstall-registry-key)), provisioned app packages, App-V packages, and non-Microsoft services and drivers.
2. **Triage every entry.** The rules in [triage-rules.json](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/triage-rules.json) sort applications into routes: keep in the base image, App Attach with an existing App-V package, App Attach after MSIX conversion, review because of drivers or services, and retire. A person decides which applications need the separate hybrid joined pool for legacy applications.
3. **Find the source for each application.** If the image is built by a Configuration Manager task sequence, the applications it installs already exist in Configuration Manager with their content and deployment types, which hold the install details ([Create applications in Configuration Manager](https://learn.microsoft.com/intune/configmgr/apps/deploy-use/create-applications)). Otherwise use the vendor's installer or the existing App-V package.
4. **Generate conversion templates in bulk.** Put the installer paths and arguments in a CSV and run [New-MsixConversionTemplate.ps1](https://github.com/marckean/AVD-Reference_Architecture/blob/main/tools/app-attach/New-MsixConversionTemplate.ps1) with `-InstallerCsvPath`.
5. **Convert, sign, image, onboard and test** as in stages 4 and 3 above.
6. **Rebuild the base image lean,** with Azure Image Builder, keeping only what belongs there. See [Images](../images/index.md).

### What stays in the base image

Some things are better in the image than in App Attach: runtimes and redistributables that many applications share, security and management agents, and Microsoft 365 Apps. Anything that needs a Windows driver can't be MSIX at all: Learn says *"MSIX doesn't support Windows drivers"* ([Prepare to package a desktop application](https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare)). Those applications stay in the image, or move to a separate host pool if they'd compromise the main one.

!!! warning "Every package still needs testing"
    The scripts automate the repetitive work, but they don't certify that an application works. Some applications won't package at all, and every package needs a test with real users and a sign-off from its owner before it reaches production.

## An example plan for a small team

This is one way to plan it. Adjust it to the size of your estate and how many application owners can test at once.

| When | Focus |
| --- | --- |
| Week 1 | Platform ready, both inventories run, triage rules tuned to your estate |
| Week 2 | Triage reviewed with application owners; first wave of App-V packages chosen |
| Weeks 3 to 4 | First wave live for a test group; code signing process agreed; conversion templates generated for wave 2 |
| Weeks 5 to 8 | Conversion waves on a clean packaging machine, each one signed, imaged, onboarded and tested |
| After that | A steady pipeline: new applications and updates go through the same route, and the base image only changes for operating system and agent updates |

## Where AI helps, and where it doesn't

| Task | An AI assistant such as GitHub Copilot | People |
| --- | --- | --- |
| Inventory | Summarise the CSV, spot duplicates and odd entries, group applications by publisher | Run the scripts and check the counts look right |
| Triage | Propose a route for each application, with reasons, and draft the wave plan | Decide which applications go to the legacy pool or get retired |
| Conversion | Draft conversion templates and explain packaging errors | Run conversions on a clean machine and sign packages |
| Onboarding | Fill in the bulk onboarding CSV and explain App Attach errors | Approve assignments and roll back if needed |
| Testing | Draft test scripts for each application | Test with real users; the application owner signs off |

The repository includes instructions and skills that teach GitHub Copilot this workflow, and it points Copilot at the Microsoft Learn MCP server so its answers stay grounded. See [Working with AI](working-with-ai.md).

## Skills the team needs

- **Packaging:** the MSIX Packaging Tool, plus enough App-V knowledge to read a dynamic configuration file.
- **Platform:** Azure Files permissions, Microsoft Entra Kerberos and App Attach assignments.
- **Signing:** a code signing certificate and a way to make it trusted on session hosts.
- **Testing:** time from application owners, which is usually the real bottleneck.

The Microsoft Learn training path [Manage user environments and apps for Azure Virtual Desktop](https://learn.microsoft.com/training/paths/manage-user-environments-apps/) covers App Attach and FSLogix, and the [AZ-140 study guide](https://learn.microsoft.com/credentials/certifications/resources/study-guides/az-140) lists the wider skills.

## Microsoft Learn

- [App Attach in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)
- [Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup)
- [Create an MSIX image to use with App Attach](https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image)
- [App-V in Windows support policy](https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy)
- [Generate a command line template for the MSIX Packaging Tool](https://learn.microsoft.com/windows/msix/packaging-tool/generate-template-file)
- [Prepare to package a desktop application](https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare)
- [Uninstall registry key](https://learn.microsoft.com/windows/win32/msi/uninstall-registry-key)
- [Create a managed disk from an image version](https://learn.microsoft.com/azure/virtual-machines/managed-disk-from-image-version)
- [Create applications in Configuration Manager](https://learn.microsoft.com/intune/configmgr/apps/deploy-use/create-applications)
