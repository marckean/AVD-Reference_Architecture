---
title: Azure Compute Gallery
description: Image definitions, versions, replication, storage redundancy and Trusted launch alignment.
---

# Azure Compute Gallery

Azure Compute Gallery is the image distribution layer. Microsoft says it provides global replication, versioning, grouping, zone-redundant storage in supported regions, and sharing features in [Azure Compute Gallery overview](https://learn.microsoft.com/azure/virtual-machines/azure-compute-gallery).

Use:

- One image definition per operating system, security type, and major build line.
- One image version per release.
- Regional replication to every region where session hosts are deployed.
- ZRS where available and aligned with the organisation's resilience design.

Keep security type aligned. Azure Compute Gallery has Trusted Launch-related settings. The gallery overview states that when you specify **TrustedLaunchSupported** or **TrustedLaunchandConfidentialVMSupported** on an image definition, images can default to Trusted Launch if validation is successful in [Azure Compute Gallery overview](https://learn.microsoft.com/azure/virtual-machines/azure-compute-gallery#trusted-launch-validation-for-azure-compute-gallery-images-preview). That validation feature is preview and not recommended for production workloads according to the same section, so do not rely on preview validation as the only production gate.

!!! info "Preview"
    Trusted Launch validation for Azure Compute Gallery images is currently preview. Use production-safe validation outside that preview feature until it is generally available.

---

Part of [Images](index.md).
