---
title: Session host update
description: How session host update replaces session hosts in batches when the configuration changes.
---

# Session host update

**Status: Generally available.** Session host update is part of the Automated Host Pools capability that [What's new](https://learn.microsoft.com/azure/virtual-desktop/whats-new#june-2026) says is now available.

Session host update updates the underlying VM disk type, OS image, and other configuration properties of all session hosts in a host pool with session host configuration. Microsoft states that it deallocates or deletes the existing VMs and creates new ones that are added back to the host pool with the updated configuration in [Session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update).

Use it for image-based change, not in-place drift. The update process notifies connected users, waits for the configured delay, drains selected hosts, removes them from the host pool, creates replacement hosts from the updated session host configuration, joins them to the directory, adds them to the host pool, and deletes the original VMs. The process is documented in [Session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update#update-process).

Important limits:

- Only one update can run or be scheduled in a single host pool at a time.
- If Autoscale is used, Microsoft says to disable Autoscale on the host pool before session host update and keep it disabled until the update is finished.
- Customisations manually added to individual session hosts are not present after update. Put them in the image, Intune, Group Policy for hybrid pools, or the custom configuration PowerShell script in the session host configuration.
- The new image must be supported for Azure Virtual Desktop and the VM generation.

---

Part of [Host pools](index.md).
