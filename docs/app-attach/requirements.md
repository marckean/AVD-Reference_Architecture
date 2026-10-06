---
title: Requirements and file shares
description: Package formats, disk images, file share requirements and permissions, including for Microsoft Entra joined session hosts.
---

# Requirements and file shares

## Requirements and limitations

The session hosts must run a supported Windows client or server operating system, must be joined to Microsoft Entra ID or AD DS, and at least one session host must be powered on when adding an application ([Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup)).

The App Attach package must be on an SMB file share in the same Azure region as the session hosts, and all session hosts in the host pool must have read access with their computer account ([Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup)). For Microsoft Entra joined session hosts using Azure Files, Learn requires assigning the **Reader and Data Access** Azure RBAC role to both the **Azure Virtual Desktop** and **Azure Virtual Desktop ARM Provider** service principals; the storage account must be in the same subscription as the session host VMs ([Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup)).

!!! warning "Storage account scope"
    Learn warns that assigning the **Azure Virtual Desktop ARM Provider** service principal to the storage account grants the Azure Virtual Desktop service access to all data inside that storage account. Use a dedicated storage account for App Attach packages and rotate access keys regularly ([App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)).

Performance is storage-sensitive. Learn gives an example for a single 1 GB image or App-V package containing one application: **One IOP** steady state, **10 IOPs** at machine boot sign-in, and **400 ms** latency ([App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)). Do not combine App Attach images and FSLogix containers on the same file share; Learn specifically recommends avoiding the same file share for App Attach and FSLogix profile containers ([App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)).

Poor candidates for MSIX conversion include applications that require Windows drivers, per-user Windows services, in-process shell extensions loaded into processes outside the package, writes to the install directory, or mandatory elevation. Those constraints are documented in the MSIX packaging preparation guidance, not in App Attach itself ([Prepare to package a desktop application](https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare)).

---

Part of [Applications with App Attach](index.md).
