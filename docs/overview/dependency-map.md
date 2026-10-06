---
title: Dependency map
description: The master dependency map for the North Star - which decisions are fixed when a host pool is created, what each part depends on, and why you can't mix join types in one host pool.
---

# Dependency map

!!! abstract "At a glance"
    - Three decisions are fixed when you create a host pool: the **host pool type**, the **management approach** and, in practice, the **domain join type**. Changing any of them later means building a new host pool.
    - The management approach decides whether you get the native features that run the North Star: session host configuration, session host update, dynamic autoscaling and ephemeral OS disks.
    - The domain join type decides how single sign-on, profiles, App Attach, Intune and legacy applications work. That's why applications that need Active Directory get [their own host pool](reference-architectures.md#two-host-pools).
    - Settle the decisions in number order. Everything below them can change as you learn.

## The map

![The master dependency map. Licences and quota, identity and network come first. They feed three decisions that are fixed when a host pool is created: the host pool type, the management approach and the domain join type. The management approach enables the session host configuration, session host update, dynamic autoscaling and ephemeral OS disks. The domain join type decides how single sign-on, FSLogix profiles, App Attach, Intune policy and legacy authentication work.](../assets/images/dependency-map-light.svg#only-light)
![The master dependency map. Licences and quota, identity and network come first. They feed three decisions that are fixed when a host pool is created: the host pool type, the management approach and the domain join type. The management approach enables the session host configuration, session host update, dynamic autoscaling and ephemeral OS disks. The domain join type decides how single sign-on, FSLogix profiles, App Attach, Intune policy and legacy authentication work.](../assets/images/dependency-map-dark.svg#only-dark)

**How to read it.** The numbers give the order in which to settle things. A solid line means the item at the arrowhead *requires* the item the line comes from. A dashed line means the two work together, or Microsoft recommends using them together. A **fixed** badge marks a decision you can't change once the host pool is in use.

## The decisions you can't change later

| Decision | Options | What Learn says | Changing it means |
| --- | --- | --- | --- |
| **Host pool type** | Pooled or personal | *"Once you create a host pool, you can't change its type"* ([FAQ](https://learn.microsoft.com/azure/virtual-desktop/faq#can-i-change-from-pooled-to-personal-host-pools)) | A new host pool. You can move registered VMs to a host pool of a different type. |
| **Management approach** | Standard or session host configuration | *"The host pool management approach is set when you create a host pool and can't be changed later. If you create a host pool without a session host configuration, you can't add one afterwards"* ([Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches)) | A new host pool, created with a session host configuration from the start. |
| **Domain join type** | Microsoft Entra ID or Active Directory | Session host update *"must use the same directory as the existing VMs. You can't change the directory during an update"* ([Session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update#virtual-machines-and-management-tools)) | A new host pool with the other join type. |
| **Deployment scope** | Geographical or Regional | *"Deployment scope can't be changed after the host pool is created"* ([Deploy Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/deploy-azure-virtual-desktop)) | A new host pool. Regional is available only in supported regions ([Regional host pools](https://learn.microsoft.com/azure/virtual-desktop/regional-host-pools)). |

The deployment scope isn't on the map because it decides where the host pool's metadata is stored, not how the session hosts work. It's still a creation-time decision, so it belongs on the same list.

!!! note "A nuance on the join type"
    Learn says that *"if there are no session hosts in the host pool, any property of the session host configuration can be changed without needing to schedule a session host update"* ([Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches#session-host-configuration)). Once the pool has session hosts, session host update can't change the directory. Treat the join type as fixed when you create the pool, and don't plan a design around emptying a pool to change it.

## Can I mix join types in one host pool?

No. Learn is explicit: *"All session hosts in a host pool should have the same configuration, including the same identity provider. For example, a host pool shouldn't contain some session hosts joined to Microsoft Entra ID and some session hosts joined to an Active Directory domain"* ([Add session hosts to a host pool](https://learn.microsoft.com/azure/virtual-desktop/add-session-hosts-host-pool#prerequisites)).

With a session host configuration it's also structural. The configuration holds a single domain join setting, and every host it creates uses that setting.

So when some applications need Active Directory, build two host pools:

1. A **North Star pool**, Microsoft Entra joined, for everything that can run there.
2. A **legacy pool**, Active Directory joined, for the applications that can't. For example, Learn says Microsoft Entra joined devices don't support on-premises applications that rely on machine authentication ([Plan your Microsoft Entra join deployment](https://learn.microsoft.com/entra/identity/devices/device-join-plan#understand-considerations-for-applications-and-resources)).

One workspace can publish application groups from both pools, so users see one feed. The [two host pools pattern](reference-architectures.md#two-host-pools) shows the design, and [Stepping stones](../getting-there/stepping-stones.md) covers how to govern the legacy pool and retire it.

## What each item depends on

| # | Item | Depends on | What it means | Learn |
| --- | --- | --- | --- | --- |
| 1 | Licences and quota | - | Users need a licence that includes Azure Virtual Desktop access rights. Dynamic autoscaling and session host update create virtual machines, so the region needs VM quota for peak scale-out. | [Licensing](https://learn.microsoft.com/azure/virtual-desktop/licensing), [Quotas](https://learn.microsoft.com/azure/quotas/view-quotas) |
| 2 | Identity | - | Every user signs in with Microsoft Entra ID. Active Directory Domain Services is needed only where an application or a legacy pool needs it. | [Prerequisites](https://learn.microsoft.com/azure/virtual-desktop/prerequisites) |
| 3 | Network | - | Session hosts need outbound access to the required endpoints, and private paths to storage where you use private endpoints. | [Network connectivity](https://learn.microsoft.com/azure/virtual-desktop/network-connectivity) |
| 4 | Host pool type | 1 | Pooled for shared multi-session hosts, personal for dedicated desktops. | [Terminology](https://learn.microsoft.com/azure/virtual-desktop/terminology) |
| 5 | Management approach | 4 | *"The session host configuration management approach can be used with pooled host pools only."* | [Management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches) |
| 6 | Domain join type | 2, 3 | One join type per host pool. An Active Directory joined pool needs a virtual network that can reach the domain controllers and DNS servers. | [Add session hosts](https://learn.microsoft.com/azure/virtual-desktop/add-session-hosts-host-pool#prerequisites), [Prerequisites](https://learn.microsoft.com/azure/virtual-desktop/prerequisites#network) |
| 7 | Session host configuration | 5 | Defines what every new host looks like. With a managed identity, the identity creates, updates and deletes session hosts. The local administrator credentials come from Key Vault. | [Deploy Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/deploy-azure-virtual-desktop) |
| 8 | Session host update | 5 | Replaces hosts in batches when the configuration changes. Host pools with standard management can't use it. | [Session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update) |
| 9 | Dynamic autoscaling | 5 | Creates and deletes hosts. With standard management, autoscale can only turn hosts on and off. | [Compare approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches#compare-host-pool-management-approaches) |
| 10 | Ephemeral OS disks | 5, works with 9 | *"Supported only in pooled host pools configured with session host configuration"*. Generally available since June 2026 ([What's new](https://learn.microsoft.com/azure/virtual-desktop/whats-new#june-2026)). Hosts can't be deallocated, so Learn recommends dynamic autoscaling with **Minimum percentage of active hosts (%)** at 100% in every phase. | [Ephemeral OS disks](https://learn.microsoft.com/azure/virtual-desktop/deploy/session-hosts/ephemeral-os-disks) |
| 11 | Single sign-on | 6 | Microsoft Entra joined session hosts need single sign-on or earlier authentication protocols enabled. Host pools without a session host configuration also need the **Virtual Machine User Login** role for users. | [Add session hosts](https://learn.microsoft.com/azure/virtual-desktop/add-session-hosts-host-pool), [Microsoft Entra joined session hosts](https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts#assign-user-access-to-host-pools) |
| 12 | FSLogix profiles | 6, works with 14 | Microsoft Entra joined hosts reach Azure Files with Microsoft Entra Kerberos. Intune delivers the Kerberos ticket retrieval and FSLogix settings. | [Microsoft Entra Kerberos for Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable) |
| 13 | App Attach | 6 | The share permissions depend on the identity provider. For Microsoft Entra joined hosts, assign **Reader and Data Access** to both the **Azure Virtual Desktop** and **Azure Virtual Desktop ARM Provider** service principals. | [Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup) |
| 14 | Intune policy | 6 | The enrolment method depends on the join type: **Enroll the VM with Intune** for Microsoft Entra joined hosts, and group policy with device credentials for hybrid joined hosts. | [Multi-session with Intune](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session) |
| 15 | Legacy authentication | 6 | Applications that rely on machine authentication can't run on Microsoft Entra joined hosts, so they go to an Active Directory joined pool. | [Device join plan](https://learn.microsoft.com/entra/identity/devices/device-join-plan#understand-considerations-for-applications-and-resources) |

## Using the map in a design workshop

1. **Start the foundations in parallel.** Licences and quota, identity and network have different owners and no dependency on each other.
2. **Write the three fixed decisions down for each host pool**, before anyone builds anything. An estate often needs more than one pool, and each pool gets its own row: type, management approach and join type.
3. **Build the engine.** Create the North Star pool with a session host configuration, so session host update, dynamic autoscaling and ephemeral OS disks are all available.
4. **Wire up the bottom row** for each pool's join type: single sign-on, profiles, App Attach, Intune and any legacy exceptions.

The [dependency checklist](../getting-there/dependencies.md) turns the map into owned, checkable items. The [discovery questionnaire](../accelerators/discovery-questionnaire.md) captures the answers you need to make the fixed decisions.
