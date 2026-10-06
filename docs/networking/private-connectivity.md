---
title: Private and outbound connectivity
description: Private endpoints, private DNS, Private Link and explicit outbound connectivity for session hosts.
---

# Private and outbound connectivity

## Private endpoints and DNS

Use private endpoints for Azure Files shares that host FSLogix profiles and App Attach packages. Azure Files supports public endpoints and private endpoints; private endpoints exist within a virtual network and have a private IP address from that virtual network ([Configure network endpoints for accessing Azure file shares](https://learn.microsoft.com/azure/storage/files/storage-files-networking-endpoints)).

For Azure Virtual Desktop Private Link, Learn documents three workflows and sub-resources: **global** on `Microsoft.DesktopVirtualization/workspaces` for initial feed discovery, **feed** on `Microsoft.DesktopVirtualization/workspaces` for feed download, and **connection** on `Microsoft.DesktopVirtualization/hostpools` for host pool connections ([Azure Private Link with Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/private-link-overview)).

Private endpoint DNS is not optional. For Azure Virtual Desktop Private Link, Learn states that the private DNS zone for **privatelink.wvd.microsoft.com** returns the private IP address for workspace feed download ([Azure Private Link with Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/private-link-overview)). For Azure Files, link the private DNS zone for the file endpoint to the host pool virtual network, or ensure custom DNS resolves the storage account file endpoint to the private endpoint IP.

## Outbound connectivity

Do not rely on default outbound access. Learn says Azure automatically assigns an outbound public IP address when a VM has no explicitly defined outbound method, and that this is default outbound access ([Default outbound access in Azure](https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access)). Use explicit egress such as Azure NAT Gateway or Azure Firewall instead.

**Status:** Azure NAT Gateway is generally available as an Azure networking service. Learn describes it as a fully managed and highly resilient NAT service that lets all instances in a subnet connect outbound to the internet while remaining fully private, and says it does not permit unsolicited inbound connections from the internet ([What is Azure NAT Gateway?](https://learn.microsoft.com/azure/nat-gateway/nat-overview)).

---

Part of [Networking](index.md).
