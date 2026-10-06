---
title: Autoscale and alerts
description: Autoscale diagnostics and the alerts worth setting up.
---

# Autoscale and alerts

## Autoscale diagnostics

Autoscale is part of the capacity control loop. Microsoft Learn describes two scaling methods: **Power management autoscaling**, which powers session hosts on and off, and **Dynamic autoscaling**, which powers on and off and also creates and deletes session hosts for pooled host pools with session host configuration [Autoscale scaling plans and example scenarios in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/autoscale-scenarios). The June 2026 entry in [What's new in Azure Virtual Desktop?](https://learn.microsoft.com/azure/virtual-desktop/whats-new) states that **Automated Host Pools**, **Dynamic Autoscaling** and **Ephemeral OS Disks** are now available.

**Status:** Generally available for Power Management Autoscaling.  
**Status:** Generally available for Automated Host Pools, Dynamic Autoscaling and Ephemeral OS Disks, based on the June 2026 availability announcement in [What's new in Azure Virtual Desktop?](https://learn.microsoft.com/azure/virtual-desktop/whats-new).

The September 2026 entry in [What's new in Azure Virtual Desktop?](https://learn.microsoft.com/azure/virtual-desktop/whats-new) states that managed identity support for Azure Virtual Desktop host pools is generally available and can be used for session host configuration, autoscale, Start VM on Connect and Azure Virtual Desktop for Azure local. Build monitoring around the host pool managed identity because future service updates will require it for host pools configured with a session host configuration.

Monitor autoscale outcomes by comparing capacity and user pressure in Insights with connection failures and host availability. Useful operational questions are:

- Did the host pool have available sessions when users connected?
- Were session hosts unavailable because the agent was unhealthy, the VM was not running or the pool was in drain mode?
- Did failed connections cluster around a ramp-up or ramp-down schedule?

## Useful alerts

Create Azure Monitor log alerts and action groups for the symptoms that require operational response. Microsoft Learn states that Azure Virtual Desktop Insights can show Azure Monitor alerts in the context of AVD data and that alerts must be configured separately [Enable Insights to monitor Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/insights).

Recommended alert intents:

- **Failed connections increased** - query `WVDErrors` and `WVDConnections` for a rolling failure count by host pool, user or error symbol.
- **No available capacity** - use Insights capacity data and connection failures to detect when available sessions are exhausted.
- **Session hosts unavailable** - alert when registered hosts stop sending data or show as unavailable in Insights.
- **Service-impacting Azure events** - Azure Service Health provides Azure Status, Service Health and Resource Health, and Service Health alerts notify through your chosen channels about issues affecting your resources [What is Azure Service Health?](https://learn.microsoft.com/azure/service-health/overview).

---

Part of [Monitoring](index.md).
