---
title: Intune
description: Microsoft Intune policy design for Windows 11 Enterprise multi-session Azure Virtual Desktop session hosts.
---

# Intune

!!! abstract "At a glance"
    - Microsoft Intune support for Windows Enterprise multi-session is generally available.
    - Use Intune Settings Catalog profiles for Windows 11 Enterprise multi-session session hosts, filtered by **OS edition == Enterprise multi-session**.
    - Enrol Microsoft Entra joined session hosts during Azure Virtual Desktop provisioning by enabling **Enroll the VM with Intune**.
    - Use device-scoped policies for host configuration and user-scoped policies only where the setting is explicitly user scope and assigned to user groups.
    - Treat pooled ephemeral hosts as image-managed. Use Intune for policy, security configuration and apps that belong in the base layer, not for in-place image lifecycle.

## What it is

Intune is the device and policy management layer for the North Star. It applies configuration profiles, endpoint security policy, compliance policy, scripts and required device-context applications to Windows 11 Enterprise multi-session session hosts. Microsoft Learn states that Azure Virtual Desktop multi-session with Microsoft Intune is now generally available, and that Windows Enterprise multi-session VMs can be managed in the Microsoft Intune admin centre like shared Windows client devices [Windows Enterprise multi-session remote desktops](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session).

Intune does not replace Azure Virtual Desktop management. Learn states that using Microsoft Intune does not depend on or interfere with Azure Virtual Desktop management of the same VM [Windows Enterprise multi-session remote desktops](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#limitations).

## North Star recommendation

**Status:** Generally available. Learn explicitly states that device configuration support and user configuration support in Microsoft Intune for Windows Enterprise multi-session VMs are generally available [Windows Enterprise multi-session remote desktops](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#overview).

Use Intune for:

- Device configuration through **Settings catalog**.
- User configuration through **Settings catalog** only where the setting has user scope and is assigned to users.
- Endpoint security profiles where **Platform Windows** is available.
- Compliance policies supported for multi-session.
- Required or uninstall application deployment in system or device context.
- System-context and user-context scripts where documented.

Do not use Intune as the primary update or rebuild mechanism for pooled ephemeral session hosts. The North Star uses Azure Image Builder, Azure Compute Gallery, session host update and dynamic autoscaling. Learn documents Windows Update quality update settings for Windows Enterprise multi-session, but the architecture keeps host consistency by rolling out new images rather than patching long-lived pooled hosts in place [Windows Enterprise multi-session remote desktops](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#windows-update-client-policies), [Images](../images/index.md).

## Requirements and limitations

| Area | Learn-confirmed behaviour | Design impact |
| --- | --- | --- |
| Supported host type | Windows Enterprise multi-session VMs in pooled host pools deployed through Azure Resource Manager, under the same tenant as Intune, with Azure Virtual Desktop agent version 1.0.2944.1400 or later [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#prerequisites). | Build host pools through Azure Resource Manager or infrastructure as code that uses ARM APIs. |
| Entra joined enrolment | Microsoft Entra joined VMs enrol by enabling **Enroll the VM with Intune** in Azure Virtual Desktop deployment [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#prerequisites). | Enable Intune enrolment at provisioning time. |
| Cloned images | Intune does not support using a cloned image of a computer that is already enrolled [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#limitations). | Build images from a clean source and enrol each VM individually. |
| Settings | Use **Settings catalog**. Unsupported templates are not delivered and show as **Not applicable** [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#create-the-configuration-profile). | Avoid legacy templates except the supported certificate and device tunnel VPN templates. |
| Templates | Only **Trusted certificate**, **SCEP certificate**, **PKCS certificate** and **VPN - Device Tunnel only** templates are supported [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#create-the-configuration-profile). | Use Settings Catalog for almost everything else. |
| Applications | Apps must install in system or device context and be targeted to devices. **Available apps** are not supported [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#application-deployment). | Put common platform apps in the image; use App Attach for user-facing app delivery [Applications with App Attach](../app-attach/index.md). |
| Compliance | Device-targeted compliance policies are supported; user-targeted compliance configurations are not supported [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#compliance-and-conditional-access). | Use device groups for host compliance. |
| Update rings | Windows update rings policies are not currently supported. Quality updates can be managed through Settings Catalog Windows Update for Business settings [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#windows-update-client-policies). | Use image-based updates for pooled hosts; use Settings Catalog quality update controls only where required. |
| Remote actions | Windows Autopilot reset, BitLocker key rotation, Fresh Start, Remote lock, Reset password and Wipe are not supported [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#remote-actions). | Rebuild hosts through AVD host pool lifecycle, not Intune remote reset. |
| Security baselines | Security baselines are available for Windows Enterprise multi-session, and Learn recommends reviewing available baselines and configuring settings in Settings Catalog [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#security-baselines). | Use baselines as input, then implement through Settings Catalog for deterministic control. |

## In this section

<div class="grid cards" markdown>

-   __[Enrolment and targeting](targeting.md)__

    ---

    How Microsoft Entra joined session hosts enrol in Intune, and how to target them with groups and filters.

-   __[Required policies](policies.md)__

    ---

    The Intune policies an Entra joined multi-session host needs, with exact settings and values, plus Teams and OneDrive.

-   __[Updates](updates.md)__

    ---

    How updates work for non-persistent pooled hosts: new images rather than patching in place.

-   __[Starting from zero](starting-from-zero.md)__

    ---

    The minimum Intune configuration an organisation with no virtual desktop policies needs before the first host pool works.

</div>

## Common pitfalls

- Building a golden image from an enrolled VM. Learn says Intune does not support using a cloned image of a computer that is already enrolled [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#limitations).
- Assigning device-scoped configuration to users or user-scoped configuration to devices.
- Using unsupported templates and then treating **Not applicable** as a platform fault.
- Trying to deploy **Available apps** to multi-session hosts. Learn says **Available apps** deployment intent is not supported [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#application-deployment).
- Depending on Intune remote actions such as Wipe or Autopilot reset. Learn lists these as unsupported for Windows Enterprise multi-session VMs [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#remote-actions).
- Applying user-targeted compliance policies. Learn says user-targeted compliance configurations are not supported [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#compliance-and-conditional-access).

## Microsoft Learn

- [Windows Enterprise multi-session remote desktops](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session)
- [Store FSLogix profile containers on Azure Files using Microsoft Entra ID](https://learn.microsoft.com/fslogix/how-to-configure-profile-container-entra-id-hybrid)
- [Enable Microsoft Entra Kerberos authentication for hybrid and cloud-only identities on Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable)
- [FSLogix Configuration Setting Reference](https://learn.microsoft.com/fslogix/reference-configuration-settings)
- [Prerequisites for FSLogix](https://learn.microsoft.com/fslogix/overview-prerequisites)
- [Use Microsoft Teams on Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/teams-on-avd)
- [Use OneDrive policies to control sync settings](https://learn.microsoft.com/sharepoint/use-group-policy)
- [Redirect and move Windows known folders to OneDrive](https://learn.microsoft.com/sharepoint/redirect-known-folders)
- [Get started with Windows LAPS and Microsoft Entra ID](https://learn.microsoft.com/windows-server/identity/laps/laps-scenarios-azure-active-directory)
- [Windows update management methodologies for Azure Virtual Desktop session hosts](https://learn.microsoft.com/azure/virtual-desktop/windows-update-management-methodologies-session-hosts)
