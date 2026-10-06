---
title: Rollout and cadence
description: Rolling images out in rings with session host update, how often to update, and the requirements to plan for.
---

# Rollout and cadence

## Rolling images out in rings

Use rings to reduce blast radius:

1. **Ring 0**: image build validation host pool, not used by business users.
2. **Ring 1**: IT and early adopter validation pool.
3. **Ring 2**: a small production cohort.
4. **Ring 3**: broad production rollout.

In a session host configuration pool, rollout means updating the session host configuration to point at the new image and scheduling session host update. Microsoft says session host update creates new hosts from the updated configuration, joins them to the directory, adds them to the host pool, and deletes the original VMs in [Session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update#update-process).

Because Microsoft says Autoscale should be disabled during session host update, schedule image rings outside major scale events, then re-enable Autoscale afterwards. This is documented in [Session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update#important).

## Image cadence

For pooled Windows client multi-session, Microsoft lists **Session host update** and **Azure Compute Gallery** as recommended delivery methods for monthly security and quality updates and feature updates in [Windows update management methodologies for session hosts](https://learn.microsoft.com/azure/virtual-desktop/windows-update-management-methodologies-session-hosts).

Use a monthly cadence for normal quality and security updates unless the organisation has a different patch cycle. Every release should produce:

- A gallery image version.
- Release notes showing base image, update level, custom image template or Azure Image Builder version, and key changes.
- Validation evidence from Ring 0 and Ring 1.
- A rollback decision, normally pointing the session host configuration back to the previous image version and running session host update again.

Do not let hosts drift for months and then attempt to reconcile them. The North Star treats pooled hosts as replaceable.

## Requirements and limitations

- Azure Image Builder uses a user-assigned managed identity when creating and distributing a custom image from a custom image template, per [Custom image templates](https://learn.microsoft.com/azure/virtual-desktop/custom-image-templates#creation-process).
- The build VM needs internet access to download built-in or custom scripts, unless the design provides reachable private sources. Microsoft states this requirement in [Custom image templates](https://learn.microsoft.com/azure/virtual-desktop/custom-image-templates#creation-process).
- Session host update can use images from Azure Marketplace, an existing Azure Compute Gallery shared image, or an existing managed image, per [Session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update#virtual-machines-and-management-tools).
- Session host configurations do not currently support accessing an Azure Compute Gallery shared image in a different Azure subscription than the host pool, per [Session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update#azure-compute-gallery-shared-image-limitations).
- App Attach package storage must be accessible by the session hosts, and application assignment requires the application to be assigned to the host pool, the user to be allowed into the application group, and the application to be assigned to the user, per [App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview#how-a-user-gets-an-application).

---

Part of [Images](index.md).
