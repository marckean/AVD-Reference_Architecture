---
title: Starting from zero
description: The minimum Intune configuration an organisation with no virtual desktop policies needs before the first host pool works.
---

# Starting from zero

Before the first Microsoft Entra joined host pool works, an organisation needs:

1. Azure Virtual Desktop licensing and Microsoft Intune licensing. Learn says the appropriate Azure Virtual Desktop and Microsoft Intune licence is required if a user or device benefits directly or indirectly from Intune [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#prerequisites).
2. A Microsoft Entra tenant and Intune tenant in the same tenant as the host pool [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#prerequisites).
3. Host pool provisioning that selects Microsoft Entra join and enables **Enroll the VM with Intune** [Microsoft Entra joined session hosts](https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts#deploy-microsoft-entra-joined-vms).
4. A device group strategy for session hosts, including an **OS edition == Enterprise multi-session** Settings Catalog filter [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#create-the-configuration-profile).
5. Single sign-on and Conditional Access design from [Identity and access](../identity/index.md).
6. Microsoft Entra Kerberos configuration for Azure Files if FSLogix profiles are on Azure Files [Azure Files Microsoft Entra Kerberos](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable).
7. Baseline Intune policies for FSLogix, Defender exclusions, redirection controls, Windows LAPS and security baseline settings.

---

Part of [Intune](index.md).
