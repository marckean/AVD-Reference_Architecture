---
title: Reference architectures
description: The reference architecture patterns at a glance - the North Star, plus the patterns you combine with it - two host pools for legacy applications, personal desktops, RemoteApp, multi-region resilience and private connectivity.
---

# Reference architectures

!!! abstract "At a glance"
    - Six patterns, all built from the same parts. You combine them as your estate needs, for example the North Star plus a second host pool for legacy applications.
    - **The North Star** is the default for pooled desktops and published applications.
    - The other five cover what the North Star doesn't do on its own: applications that need Active Directory, dedicated desktops, published applications, regional resilience and private networks.
    - The [discovery questionnaire](../accelerators/discovery-questionnaire.md) tells you which patterns your answers point to. The [dependency map](dependency-map.md) shows which choices you can't change later.

## Which pattern, when

| Pattern | Use it when | What to know first |
| --- | --- | --- |
| [The North Star](#the-north-star) | You're building pooled desktops or published applications on a new host pool | The management approach is fixed when the host pool is created |
| [Two host pools](#two-host-pools) | Some applications need Active Directory machine authentication or other AD DS dependencies | Each host pool has one join type, so legacy applications get their own pool |
| [Personal desktops](#personal-desktops) | Users need a dedicated, persistent desktop, for example developers | The session host configuration approach is for pooled host pools only |
| [RemoteApp](#remoteapp) | Users need individual applications rather than a full desktop | RemoteApp application groups need a pooled host pool, and each application group belongs to one host pool |
| [Multi-region resilience](#multi-region-resilience) | You need the service to survive the loss of a region | Protect the state, not the hosts: profiles, packages and images |
| [Private connectivity](#private-connectivity) | Traffic must stay on private networks, or clients connect from managed networks | Private Link and RDP Shortpath for managed networks need network design up front |

## The North Star

![The North Star architecture: users sign in with Microsoft Entra ID and connect through Azure Virtual Desktop to a pooled host pool of Microsoft Entra joined session hosts on ephemeral OS disks, with profiles and App Attach packages on Azure Files, images from Azure Compute Gallery, policy from Intune and telemetry to Azure Monitor.](../assets/images/north-star-architecture-light.svg#only-light)
![The North Star architecture: users sign in with Microsoft Entra ID and connect through Azure Virtual Desktop to a pooled host pool of Microsoft Entra joined session hosts on ephemeral OS disks, with profiles and App Attach packages on Azure Files, images from Azure Compute Gallery, policy from Intune and telemetry to Azure Monitor.](../assets/images/north-star-architecture-dark.svg#only-dark)

A pooled host pool with a session host configuration, created and deleted by dynamic autoscaling on ephemeral OS disks. Session hosts are Microsoft Entra joined and configured by Intune, applications arrive with App Attach, and profiles roam with FSLogix on Azure Files. It's the default for everything that can run on it. [What good looks like](what-good-looks-like.md) describes it layer by layer, and [How it fits together](how-it-fits-together.md) walks through the numbered flows.

## Two host pools

![Two host pools: a North Star pool and a separate hybrid joined pool for legacy applications, both published through one workspace, with AD DS domain controllers, Microsoft Entra Connect or Cloud Sync, and separate storage and image paths.](../assets/images/two-host-pools-light.svg#only-light)
![Two host pools: a North Star pool and a separate hybrid joined pool for legacy applications, both published through one workspace, with AD DS domain controllers, Microsoft Entra Connect or Cloud Sync, and separate storage and image paths.](../assets/images/two-host-pools-dark.svg#only-dark)

Most estates have applications that can't run on Microsoft Entra joined session hosts. Learn says Microsoft Entra joined devices don't support on-premises applications that rely on machine authentication ([Device join plan](https://learn.microsoft.com/entra/identity/devices/device-join-plan#understand-considerations-for-applications-and-resources)). Those applications go in a second, hybrid joined pooled host pool. One workspace publishes both pools, and users see the applications they're assigned, whichever pool they come from.

Keep the pools separate. Learn says all session hosts in a host pool *"should have the same configuration, including the same identity provider"* ([Add session hosts to a host pool](https://learn.microsoft.com/azure/virtual-desktop/add-session-hosts-host-pool#prerequisites)), and a session host configuration holds a single domain join setting. The legacy pool needs line of sight to AD DS domain controllers, identities synchronised by Microsoft Entra Connect or Cloud Sync, and its own image track. It also isolates fragile legacy applications from the main image. Give it an owner and an exit date: see [Stepping stones](../getting-there/stepping-stones.md).

1. **North Star pooled pool:** Microsoft Entra joined, Intune managed, dynamic autoscaling.
2. **Legacy pooled pool:** hybrid joined, for applications with AD DS dependencies.
3. **One workspace** publishes the application groups from both pools.

## Personal desktops

![Personal desktops: a personal host pool with standard management for persistent desktops, with Windows 365 Cloud PCs as the alternative, both managed by Intune.](../assets/images/personal-desktops-light.svg#only-light)
![Personal desktops: a personal host pool with standard management for persistent desktops, with Windows 365 Cloud PCs as the alternative, both managed by Intune.](../assets/images/personal-desktops-dark.svg#only-dark)

Some users need a desktop that's theirs, with changes that persist, such as developers who install their own tools. The session host configuration approach *"can be used with pooled host pools only"* ([Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches)), so a personal host pool uses the standard management approach, with its own tooling for building and updating hosts. Windows 365 Cloud PCs are the alternative: dedicated cloud desktops, provisioned and managed through Windows 365 and Intune ([What is Windows 365](https://learn.microsoft.com/windows-365/enterprise/overview)).

1. **Personal host pool:** assigned desktops, persistent OS disks, power management.
2. **Windows 365 Cloud PC:** a dedicated cloud desktop, provisioned and managed through Windows 365 and Intune.
3. **Keep the pool small:** measure how dedicated desktops are really used, and move users back to pooled desktops where you can.

## RemoteApp

![RemoteApp: a pooled host pool publishing a desktop application group and a RemoteApp application group through one workspace, with applications delivered by App Attach and assigned to users or groups.](../assets/images/remoteapp-light.svg#only-light)
![RemoteApp: a pooled host pool publishing a desktop application group and a RemoteApp application group through one workspace, with applications delivered by App Attach and assigned to users or groups.](../assets/images/remoteapp-dark.svg#only-dark)

When users need an application rather than a desktop, publish it through a RemoteApp application group. An application group gives access to a desktop or applications on the session hosts of a single host pool. A pooled host pool can have one desktop application group and several RemoteApp application groups at the same time, and RemoteApp application groups are available with pooled host pools only ([Terminology](https://learn.microsoft.com/azure/virtual-desktop/terminology#application-groups)). MSIX and Appx applications delivered with App Attach can be published with a RemoteApp application group. For a desktop, you only need to assign the App Attach package ([Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup)).

## Multi-region resilience

![Multi-region resilience: a primary and a secondary region, with profiles and App Attach packages protected and replicated, image versions replicated by Azure Compute Gallery, and session hosts rebuilt from infrastructure as code.](../assets/images/multi-region-resilience-light.svg#only-light)
![Multi-region resilience: a primary and a secondary region, with profiles and App Attach packages protected and replicated, image versions replicated by Azure Compute Gallery, and session hosts rebuilt from infrastructure as code.](../assets/images/multi-region-resilience-dark.svg#only-dark)

North Star session hosts are disposable, so resilience is about state, not hosts. Protect and replicate the profiles and App Attach packages, replicate image versions with Azure Compute Gallery ([Azure Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/azure-compute-gallery)), and rebuild the host pool in the secondary region from infrastructure as code. [Business continuity](../bcdr/index.md) covers the regional design, recovery objectives and testing.

## Private connectivity

![Private connectivity: managed network users reach Azure Virtual Desktop through Private Link and session hosts over ExpressRoute or VPN with RDP Shortpath, internet users take the public path, and session hosts in a spoke virtual network reach Azure Files through a private endpoint.](../assets/images/private-connectivity-light.svg#only-light)
![Private connectivity: managed network users reach Azure Virtual Desktop through Private Link and session hosts over ExpressRoute or VPN with RDP Shortpath, internet users take the public path, and session hosts in a spoke virtual network reach Azure Files through a private endpoint.](../assets/images/private-connectivity-dark.svg#only-dark)

Session hosts never accept inbound connections: they reverse connect to the service. On top of that, Azure Virtual Desktop Private Link keeps the service traffic on private networks ([Private Link with Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/private-link-overview)), and RDP Shortpath for managed networks lets clients on ExpressRoute or VPN connect straight to session hosts over UDP ([RDP Shortpath](https://learn.microsoft.com/azure/virtual-desktop/rdp-shortpath)). Users on the internet take the public path, with STUN or TURN for UDP. [Networking](../networking/index.md) covers the flows, the endpoints and the connection paths.
