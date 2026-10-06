---
title: Updates
description: How updates work for non-persistent pooled hosts: new images rather than patching in place.
---

# Updates

## Updates for non-persistent pooled hosts

Microsoft published specific AVD session host update methodology guidance in September 2026. For Windows client multi-session, the guidance marks **Session host update** and **Azure Compute Gallery** as **Recommended** for monthly security and quality updates, marks **Session host update** and **Azure Compute Gallery** as **Recommended** for feature updates, and says OS version upgrades should be done by deploying new VMs from a new image, with session host update recommended for multi-session hosts [Windows update management methodologies for session hosts](https://learn.microsoft.com/azure/virtual-desktop/windows-update-management-methodologies-session-hosts).

The North Star follows that guidance and uses image-based updates:

1. Azure Image Builder creates a new image version.
2. Azure Compute Gallery stores the version.
3. Session host update rolls the host pool to the new image.
4. Dynamic autoscaling creates new hosts from the updated configuration and deletes old hosts.

Patch in-place remains a supported servicing model for some AVD scenarios, but Learn says image-based servicing through session host update is recommended for pooled AVD environments because it provides consistent host configuration, easier rollback and reduced impact to active user sessions [Windows update management methodologies for session hosts](https://learn.microsoft.com/azure/virtual-desktop/windows-update-management-methodologies-session-hosts#choose-the-right-servicing-model). Intune Windows Update settings are still useful for specific controls and for persistent or exception pools, but Windows update rings are not currently supported for Windows Enterprise multi-session. Learn says quality updates can be managed through Settings Catalog settings, and lists the supported Windows Update for Business settings [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#windows-update-client-policies).

---

Part of [Intune](index.md).
