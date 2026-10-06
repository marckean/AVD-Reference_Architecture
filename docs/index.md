---
title: Azure Virtual Desktop North Star
description: A reference architecture for modern Azure Virtual Desktop - what good looks like, how the pieces fit together and how to get there, grounded in Microsoft Learn.
hide:
  - toc
---

<div class="hero" markdown>

# Azure Virtual Desktop North Star

A reference architecture for a modern Azure Virtual Desktop platform: what good looks like, how the pieces fit together, and how to get there from where you are today. Every recommendation links back to Microsoft Learn.

[What good looks like](overview/what-good-looks-like.md){ .md-button .md-button--primary }
[How it fits together](overview/how-it-fits-together.md){ .md-button }
[Dependency checklist](getting-there/dependencies.md){ .md-button }

</div>

## What this is

The North Star is an opinionated target state for **pooled Azure Virtual Desktop**, built entirely from generally available features. In one sentence: session hosts are defined by a session host configuration, created and deleted by dynamic autoscaling on ephemeral OS disks, Microsoft Entra joined and configured by Intune, with applications delivered by App Attach and profiles roaming with FSLogix on Azure Files.

It does two jobs at once. It's a **reference architecture** that says what to build and why, and it's **documentation** that explains what each component is and how it connects to the rest. A reader at level 200 can follow it, and a reader at level 400 can build from it. It's deliberately generic: the examples use a fictitious company, Contoso, so you can apply it to any environment.

## The big picture

![The North Star architecture. Users sign in with Microsoft Entra ID and connect through Azure Virtual Desktop to a pooled host pool of Microsoft Entra joined session hosts on ephemeral OS disks. Profiles and App Attach packages come from Azure Files over a private endpoint, images from Azure Compute Gallery, policy from Microsoft Intune, and telemetry goes to Azure Monitor.](assets/images/north-star-architecture-light.svg#only-light)
![The North Star architecture. Users sign in with Microsoft Entra ID and connect through Azure Virtual Desktop to a pooled host pool of Microsoft Entra joined session hosts on ephemeral OS disks. Profiles and App Attach packages come from Azure Files over a private endpoint, images from Azure Compute Gallery, policy from Microsoft Intune, and telemetry goes to Azure Monitor.](assets/images/north-star-architecture-dark.svg#only-dark)

1. **Sign in.** Users sign in with Microsoft Entra ID, which applies Conditional Access and provides single sign-on to the session host.
2. **Connect.** Windows App or the web client gets the user's feed and connects through the Azure Virtual Desktop gateway. RDP Shortpath then tries to move the session to UDP, with TCP as the fallback ([RDP Shortpath](https://learn.microsoft.com/azure/virtual-desktop/rdp-shortpath)).
3. **Reverse connect.** Session hosts connect out to the service over TCP 443, so "no inbound network ports are required to be open" ([Security recommendations](https://learn.microsoft.com/azure/virtual-desktop/security-recommendations)).
4. **Profiles and applications.** At sign-in, FSLogix attaches the user's profile container, using Microsoft Entra Kerberos for access, and App Attach mounts the applications assigned to them. Both come from Azure Files over a private endpoint.
5. **Session host lifecycle.** The session host configuration defines every host. Session host update and autoscale create, update and delete hosts to match the configuration and demand ([Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches)).
6. **Image.** New hosts use an image version from Azure Compute Gallery, built by Azure Image Builder.
7. **Policy.** Intune configures every host with settings catalog policies.
8. **Observe.** Diagnostics and performance data go to Azure Monitor and Log Analytics, where AVD Insights presents them.

[How it fits together](overview/how-it-fits-together.md) walks through each step in detail, including the connection sequence and the life of a session host.

## Why build it this way

<div class="grid cards" markdown>

-   :material-cog-sync:{ .lg .middle } __Less to build and run__

    ---

    One configuration describes every session host in the pool. Microsoft Learn notes that creating, updating and scaling session hosts "can require much effort if you don't have existing tools and processes in place", and the session host configuration approach replaces that effort with native features ([Learn](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches)).

-   :material-cash-minus:{ .lg .middle } __Pay for what's used__

    ---

    Dynamic autoscaling creates and deletes session hosts based on actual usage and your schedules ([Learn](https://learn.microsoft.com/azure/virtual-desktop/autoscale-scenarios)). Ephemeral OS disks live on the VM's local storage and incur no OS disk storage cost ([Learn](https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks)).

-   :material-package-variant:{ .lg .middle } __Change without rebuilding__

    ---

    With App Attach, applications "aren't installed locally on session hosts or images", which makes images easier to create and reduces operational overhead ([Learn](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)). New images roll out to the pool in batches with session host update ([Learn](https://learn.microsoft.com/azure/virtual-desktop/session-host-update)).

-   :material-shield-lock:{ .lg .middle } __A smaller attack surface__

    ---

    Reverse connect means "no inbound network ports are required to be open" on session hosts ([Learn](https://learn.microsoft.com/azure/virtual-desktop/security-recommendations)). Conditional Access, screen capture protection, watermarking and clipboard controls are part of the first build, not a later phase.

-   :material-account-check:{ .lg .middle } __A better experience for users__

    ---

    Single sign-on lets the connection "skip the session host credential prompt" ([Learn](https://learn.microsoft.com/azure/virtual-desktop/authentication#authentication-methods)). RDP Shortpath's UDP transport "offers better connection reliability and more consistent latency" ([Learn](https://learn.microsoft.com/azure/virtual-desktop/rdp-shortpath)).

-   :material-monitor-dashboard:{ .lg .middle } __Visible from day one__

    ---

    Azure Virtual Desktop Insights is "a dashboard built on Azure Monitor Workbooks" that helps you understand your environment ([Learn](https://learn.microsoft.com/azure/virtual-desktop/insights)). Diagnostics and alerts are switched on with the first host pool, so you can see what users see.

</div>

## The architecture, area by area

The site is organised into twelve areas in three groups. Each area has an overview page covering what it is, the North Star recommendation, requirements and limitations, common pitfalls and the Microsoft Learn articles behind it. The detail sits in the subsections beneath it, listed on each card.

### Platform

<div class="grid cards" markdown>

-   :material-shield-account:{ .lg .middle } __[Identity and access](identity/index.md)__

    ---

    Microsoft Entra joined session hosts, single sign-on, Conditional Access, and what to do about applications that still need Active Directory.

    [Single sign-on](identity/single-sign-on.md), [Conditional Access](identity/conditional-access.md), [Identities and roles](identity/identities-and-roles.md), [Legacy application authentication](identity/legacy-applications.md)
    { .covers }

-   :material-server-network:{ .lg .middle } __[Host pools](host-pools/index.md)__

    ---

    Pooled host pools with a session host configuration: one definition for every host, rolled out with session host update, on ephemeral OS disks.

    [Session host configuration](host-pools/session-host-configuration.md), [Session host update](host-pools/session-host-update.md), [Ephemeral OS disks](host-pools/ephemeral-os-disks.md), [Sizing and load balancing](host-pools/sizing-and-load-balancing.md)
    { .covers }

-   :material-chart-bell-curve-cumulative:{ .lg .middle } __[Scaling](scaling/index.md)__

    ---

    Scaling plans and dynamic autoscaling, which create and delete session hosts to match demand within the limits you set.

    [Scaling plans](scaling/scaling-plans.md), [Dynamic autoscaling](scaling/dynamic-autoscaling.md), [Monitoring and checklist](scaling/monitoring-and-checklist.md)
    { .covers }

-   :material-layers-triple:{ .lg .middle } __[Images](images/index.md)__

    ---

    A lean base image built by Azure Image Builder, versioned and replicated in Azure Compute Gallery, and rolled out on a regular cadence.

    [Building images](images/building-images.md), [Azure Compute Gallery](images/azure-compute-gallery.md), [Rollout and cadence](images/rollout-and-cadence.md)
    { .covers }

</div>

### Workloads and data

<div class="grid cards" markdown>

-   :material-package-variant-closed:{ .lg .middle } __[Applications with App Attach](app-attach/index.md)__

    ---

    Applications delivered to users at sign-in, assigned per application and per group, with a route for existing App-V packages.

    [Requirements and file shares](app-attach/requirements.md), [Packages and updates](app-attach/packages.md), [From App-V to App Attach](app-attach/from-app-v.md)
    { .covers }

-   :material-account-box-multiple:{ .lg .middle } __[User profiles with FSLogix](profiles/index.md)__

    ---

    FSLogix profile containers on Azure Files with Microsoft Entra Kerberos, sized and sharded so no share reaches its limits.

    [Access and permissions](profiles/access-and-permissions.md), [Sizing and sharding](profiles/sizing-and-sharding.md), [FSLogix settings and resilience](profiles/fslogix-settings.md)
    { .covers }

-   :material-lan:{ .lg .middle } __[Networking](networking/index.md)__

    ---

    How connections flow, RDP Shortpath and RDP Multipath, the endpoints session hosts need, and private connectivity for storage.

    [Connection paths and quality](networking/connection-paths.md), [Required flows and endpoints](networking/required-flows.md), [Private and outbound connectivity](networking/private-connectivity.md)
    { .covers }

-   :material-lock-check:{ .lg .middle } __[Security](security/index.md)__

    ---

    Session controls such as screen capture protection, watermarking and clipboard direction, host hardening and least-privilege administration.

    [Session controls](security/session-controls.md), [Session host hardening](security/host-hardening.md), [Least-privilege administration](security/administration.md)
    { .covers }

</div>

### Operations

<div class="grid cards" markdown>

-   :material-tune-vertical:{ .lg .middle } __[Intune](intune/index.md)__

    ---

    Settings catalog policies for Windows 11 Enterprise multi-session: how to target them, the policies every host needs, and how updates work.

    [Enrolment and targeting](intune/targeting.md), [Required policies](intune/policies.md), [Updates](intune/updates.md), [Starting from zero](intune/starting-from-zero.md)
    { .covers }

-   :material-monitor-eye:{ .lg .middle } __[Monitoring](monitoring/index.md)__

    ---

    Diagnostic settings, Azure Monitor Agent and AVD Insights, connection quality, and the alerts that tell you autoscale is working.

    [Diagnostics and AVD Insights](monitoring/diagnostics.md), [Connection quality and errors](monitoring/connection-quality.md), [Autoscale and alerts](monitoring/autoscale-and-alerts.md)
    { .covers }

-   :material-backup-restore:{ .lg .middle } __[Business continuity](bcdr/index.md)__

    ---

    Regional design, protecting profiles and data, and recovery objectives you test rather than assume.

    [Regional design](bcdr/regional-design.md), [Profiles and data](bcdr/profiles-and-data.md), [Recovery objectives and testing](bcdr/recovery-and-testing.md)
    { .covers }

-   :material-piggy-bank:{ .lg .middle } __[Cost optimisation](cost/index.md)__

    ---

    The cost levers designed into the platform: compute and density, licensing and storage, logging, commitments and tags.

    [Compute](cost/compute.md), [Licensing and storage](cost/licensing-and-storage.md), [Logging, commitments and tags](cost/logging-and-commitments.md)
    { .covers }

</div>

## Getting there

<div class="grid cards" markdown>

-   :material-map-marker-path:{ .lg .middle } __[A phased route](getting-there/index.md)__

    ---

    Build from the bottom up: foundations and identity, then management, storage and the image, and only then the host pool.

-   :material-format-list-checks:{ .lg .middle } __[Dependency checklist](getting-there/dependencies.md)__

    ---

    Everything that must be in place before the first Microsoft Entra joined session host, layer by layer, with owners and Learn links.

-   :material-stairs:{ .lg .middle } __[Stepping stones](getting-there/stepping-stones.md)__

    ---

    Temporary, deliberate deviations for the parts of an estate that aren't ready yet, each with an owner and an exit plan.

</div>

The [Glossary](reference/glossary.md) explains every term the site uses, and the [Microsoft Learn index](reference/learn-links.md) lists every article it cites.

## Who this is for

Architects and engineers who design, build or modernise Azure Virtual Desktop, at level 200 to 400. Each page explains the concepts it relies on before it goes deep, so you don't need to know every detail to follow it.

!!! info "A community reference, grounded in Microsoft Learn"
    This site is a community reference architecture. It isn't official Microsoft guidance. Every technical claim links to the Microsoft Learn article it's based on, and each recommended feature is marked <span class="status ga">GA</span> or <span class="status preview">Preview</span>. Azure Virtual Desktop changes quickly, so always confirm against the linked article before you build. This version reflects Microsoft Learn as at October 2026.
