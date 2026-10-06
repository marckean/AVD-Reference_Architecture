---
title: Worked example
description: How a large organisation with a mature virtual desktop estate adopts the North Star in phases - the starting point, the constraints, the decisions, the reference patterns it uses, and the lessons.
---

# Worked example

!!! abstract "At a glance"
    - This is a fictitious but realistic example: Contoso, a large organisation moving a mature, long-running virtual desktop estate to Azure Virtual Desktop.
    - Contoso doesn't move everything straight to the North Star. It uses the North Star as the target, and stepping stones for the workloads that can't get there yet.
    - It ends up with several host pools built from three reference patterns, and runs two image tracks in parallel during the proof of concept.
    - The hardest work isn't the platform. It's applications, legacy authentication, users on networks Contoso doesn't control, and a small team with a deadline.

## The starting point

Contoso runs a large virtual desktop service that has evolved over many years. It works, but it depends on a few specialists, a complex image with years of applications and policy layered into it, and a third-party control plane that's hard to scale down commercially.

The estate has four kinds of workload:

- **Full desktops** for staff who work entirely in the virtual desktop, including thousands of users in other countries who work through partner organisations.
- **Published applications** that most staff use alongside their laptops.
- **Heavy applications** that need more memory or graphics, at lower density.
- **Legacy applications**: old 32-bit applications, Office add-ins and databases that are fragile, isolated in their own group of hosts so they can't destabilise the main image.

There's also a large number of **dedicated desktops** for developers and specialists, which run around the clock unless something switches them off.

Contoso's goal isn't to rebuild the old estate feature for feature. It wants a simpler, native operating model that its own team can run, with the user experience its business relies on.

## The constraints

- Thousands of users depend on the service every day, and some of them connect from partner networks Contoso can't change.
- Some applications rely on Active Directory machine authentication or old NTLM behaviour, so they can't run on Microsoft Entra joined session hosts ([Device join plan](https://learn.microsoft.com/entra/identity/devices/device-join-plan#understand-considerations-for-applications-and-resources)).
- There are dozens of App-V packages and a few hundred installed applications, and nobody has used App Attach before.
- There are no Intune policies for session hosts yet.
- The team is small, much of the operational knowledge sits with a partner, and there's a hard commercial deadline.

## The decisions

1. **Native first, with pivot criteria.** Contoso adopts the North Star as the target and writes down, before it starts, what evidence would make it add another management layer.
2. **Stepping stones on purpose.** The target host pools are Microsoft Entra joined and managed by Intune. A separate hybrid joined pool keeps the legacy applications running until they're fixed or retired, with an owner and an exit plan ([Stepping stones](stepping-stones.md)).
3. **Two image tracks in the proof of concept.** A clean image built from the Marketplace proves the target state. A cut-down copy of the existing image runs alongside it, to find migration blockers early. Microsoft's guidance is to start the golden image from a brand-new source ([Create a golden image](https://learn.microsoft.com/azure/virtual-desktop/set-up-golden-image#other-recommendations)), so the existing-image track is a stepping stone, not the destination.
4. **Host pools by behaviour.** Contoso maps its existing workload groups onto pools: full desktops, published applications through RemoteApp, heavy applications, the legacy pool, and dedicated desktops.
5. **Applications as a stream, not a tail-end task.** The App-V packages go to App Attach first, because they need no conversion. The rest are rebuilt from source in waves.
6. **Test the hard paths first.** Users on partner networks, media, clipboard controls, autoscale behaviour at the morning peak, and sign-in time are tested in the proof of concept, not left for the pilot.
7. **Dedicated desktops are measured, not assumed.** Contoso measures how many hours developer desktops actually run, and compares personal host pools with Windows 365 Cloud PCs.

## The architecture it chose

Contoso uses three of the [reference architecture](../overview/reference-architectures.md) patterns together:

| Pattern | Used for |
| --- | --- |
| **The North Star** | Full desktops and published applications: pooled host pools with a session host configuration, dynamic autoscaling, ephemeral OS disks, Microsoft Entra join, App Attach and FSLogix on Azure Files |
| **Two host pools** | A hybrid joined pooled host pool for the legacy applications, published through the same workspace, with its own image track and an exit date |
| **Personal desktops** | Dedicated desktops for developers and specialists, compared between personal host pools and Windows 365 |

Everything is built as code. A session host configuration fixes the host pool's type and management approach at creation ([Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches)), so each pool is designed deliberately rather than converted later. The [dependency map](../overview/dependency-map.md) shows how those choices depend on each other.

## The phases

| Phase | What happens | The accelerators that help |
| --- | --- | --- |
| **0. Decide and discover** | Record the target, the stepping stones, the success criteria and the pivot criteria. Discover personas, applications, authentication dependencies, network paths and current costs | [Discovery questionnaire](../accelerators/discovery-questionnaire.md) |
| **1. Prove the hard parts** | Run both image tracks. Test App Attach, the Intune baseline, Microsoft Entra join, the hybrid exception, partner networks, media, clipboard controls, profile attach, scaling and cost | [Deploy to Azure](../accelerators/deploy-to-azure.md), [policy examples](../intune/policy-examples.md) |
| **2. Build the production foundation** | Build as code: image rings, the application validation flow, monitoring, alerting, runbooks and access roles | [Dependency checklist](dependencies.md) |
| **3. Pilot every persona** | Standard users, published application users, heavy application users, legacy application users, partner users and developers | [App Attach fast track](../accelerators/app-attach-fast-track.md) |
| **4. Migrate in waves** | Simpler groups first, with a parallel stream for the hard applications, developer desktops and partner connectivity | [Working with AI](../accelerators/working-with-ai.md) |
| **5. Retire the old platform** | Retire capacity group by group, only once users are stable on the new service | |

## What Contoso learned

- **The North Star is the target, not the first build for every workload.** Stepping stones are fine if each one has an owner and an exit date.
- **Test the reasons you might fail, not only what's easy to demonstrate.** The proof of concept earns its keep on partner networks, legacy applications and scaling at the peak.
- **Session count isn't the whole story.** Autoscale measures capacity in sessions: the host pool's maximum session limit multiplied by the number of available session hosts ([Autoscale glossary](https://learn.microsoft.com/azure/virtual-desktop/autoscale-glossary)). An older platform may have balanced load on memory and processor too, so measure density on real workloads before you size the estate.
- **App Attach changes how you operate, not just how you package.** The process of owners, testing, signing and updates matters more than the number of packages.
- **A clean image finds the target state. An existing image finds the blockers.** Running both, for a while, tells you more than either alone.
- **Partner networks and secure web gateways can decide the user experience.** Test from real user locations early.
- **Telling users that capacity is starting can matter as much as making it start faster.** Design the experience at the morning peak, not just the platform.
- **Cost evidence has to be per persona.** A blended average hides the workloads that cost the most.
