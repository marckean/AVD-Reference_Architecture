---
title: Security
description: Defence-in-depth security controls for a Microsoft Entra joined Azure Virtual Desktop reference architecture.
---

# Security

!!! abstract "At a glance"
    - Treat Azure Virtual Desktop security as defence in depth across identity, session controls, session hosts, storage, networking and operations.
    - Use Conditional Access for entry control, then enforce session controls such as screen capture protection, watermarking, clipboard restrictions and device redirection.
    - Build session hosts with Trusted Launch, Microsoft Defender for Endpoint onboarding for non-persistent VDI, Microsoft Defender Antivirus exclusions for FSLogix, and Intune security baselines.
    - Use Private Link and private endpoints for service access where the design requires private connectivity.
    - Assign the least-privilege Azure Virtual Desktop built-in roles instead of broad subscription roles.

## What it is

Azure Virtual Desktop is a managed virtual desktop service, but the security boundary is shared. Microsoft secures the Azure Virtual Desktop service. You secure identity, Conditional Access, session host configuration, storage, networking, monitoring and administrator access. Microsoft Learn frames this as securing both the Azure Virtual Desktop deployment and the surrounding Azure infrastructure and management plane [Security recommendations for Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/security-recommendations).

The North Star uses:

- Microsoft Entra joined session hosts and Conditional Access, covered in [Identity and access](../identity/index.md).
- Windows 11 Enterprise multi-session session hosts enrolled in Intune, covered in [Intune](../intune/index.md).
- FSLogix profile containers on Azure Files, covered in [User profiles with FSLogix](../profiles/index.md).
- Private endpoints and RDP Shortpath, covered in [Networking](../networking/index.md).
- Azure Monitor and AVD Insights, covered in [Monitoring](../monitoring/index.md).

## North Star recommendation

**Status:** Generally available for the core controls used in this page unless noted otherwise. Microsoft Learn documents screen capture protection, watermarking, redirection controls, Trusted Launch, Defender for Endpoint VDI onboarding, Azure Virtual Desktop RBAC roles and Intune support for Windows Enterprise multi-session. Watermarking and Trusted Launch for Azure Virtual Desktop are explicitly listed as generally available in the Azure Virtual Desktop "What's new" page [What's new in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/whats-new#july-2023).

Use Conditional Access to decide who can connect. Use RDP properties and Intune to decide what can leave the session. Use host security and Defender controls to protect the session host. Use least-privilege RBAC and private networking to reduce management and network exposure.

## Design decisions

| Decision | North Star choice | Why |
| --- | --- | --- |
| Identity entry control | Conditional Access on **Azure Virtual Desktop** and **Windows Cloud Login** | Learn says both apps are involved when SSO is enabled [Enforce MFA for Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/set-up-mfa). |
| Screen capture | Enable for sensitive host pools | Screen capture protection blocks remote content in screenshots and screen sharing through supported OS features and APIs, and web connection support became available in August 2026 [Screen capture protection](https://learn.microsoft.com/azure/virtual-desktop/screen-capture-protection), [What's new](https://learn.microsoft.com/azure/virtual-desktop/whats-new#august-2026). |
| Watermarking | Enable for privileged or high-risk desktops | Watermarking adds QR codes with a **Connection ID** or **Device ID** that administrators can trace [Watermarking](https://learn.microsoft.com/azure/virtual-desktop/watermarking). |
| Clipboard | Allow only the minimum direction and data types needed | Learn supports directional and data-type clipboard controls from session host to client and client to session host [Clipboard transfer direction](https://learn.microsoft.com/azure/virtual-desktop/clipboard-transfer-direction-data-types). |
| Context-based redirection | Use only for targeted preview scenarios | Context-based redirections dynamically control clipboard, drive, printer and USB redirection with Conditional Access authentication context [Context-based redirections](https://learn.microsoft.com/azure/virtual-desktop/context-based-redirections-avd). |
| Peripheral redirection | Deny by default, allow by exception | RDP properties control clipboard, drives, printers, cameras, USB and other redirected resources [Supported RDP properties](https://learn.microsoft.com/azure/virtual-desktop/rdp-properties). |
| Display protection | Track for high-risk personas, but do not make it a baseline dependency yet | Display Protection is in public preview and protects the display path between session host and supported endpoint devices [Display Protection](https://learn.microsoft.com/windows-365/enterprise/windows-cloud-display-protection). |
| Host integrity | Trusted Launch with Secure Boot and vTPM | Trusted Launch protects Generation 2 VMs with technologies including Secure Boot and vTPM [Trusted Launch](https://learn.microsoft.com/azure/virtual-machines/trusted-launch). |
| Non-persistent protection | Defender for Endpoint VDI onboarding in the image | Learn documents the VDI onboarding package for non-persistent Windows virtual desktops [Onboard non-persistent VDI](https://learn.microsoft.com/defender-endpoint/configure-endpoints-vdi). |
| Administrator access | Built-in Azure Virtual Desktop roles | Learn documents granular roles for host pools, application groups and workspaces [Built-in Azure RBAC roles](https://learn.microsoft.com/azure/virtual-desktop/rbac). |

## Control map

| Control | Where configured | North Star value | Status | Learn |
| --- | --- | --- | --- | --- |
| Conditional Access | Microsoft Entra ID | Target **Azure Virtual Desktop** and **Windows Cloud Login** | **Status:** Generally available | [MFA and Conditional Access](https://learn.microsoft.com/azure/virtual-desktop/set-up-mfa) |
| SSO | Host pool RDP properties | **enablerdsaadauth:i:1** | **Status:** Generally available | [Configure SSO](https://learn.microsoft.com/azure/virtual-desktop/configure-single-sign-on) |
| Screen capture protection | Intune or Group Policy on session hosts | Enabled for sensitive pools | **Status:** Generally available, including web connections as of August 2026 | [What's new](https://learn.microsoft.com/azure/virtual-desktop/whats-new#august-2026) |
| Watermarking | Intune or Group Policy on session hosts | Enabled for high-risk pools | **Status:** Generally available | [What's new](https://learn.microsoft.com/azure/virtual-desktop/whats-new#july-2023) |
| Clipboard on or off | Host pool RDP properties | **redirectclipboard:i:0** unless required | **Status:** Generally available | [Clipboard redirection](https://learn.microsoft.com/azure/virtual-desktop/redirection-configure-clipboard) |
| Clipboard direction and data types | Intune Settings Catalog or Group Policy | Allow plain text only where business need exists | **Status:** Generally available, documented without preview label | [Clipboard transfer direction](https://learn.microsoft.com/azure/virtual-desktop/clipboard-transfer-direction-data-types) |
| Context-based redirections | Conditional Access authentication context and host pool RDP properties | Use for pilot scenarios that require device compliance or location-aware redirection | **Status:** Preview | [Context-based redirections](https://learn.microsoft.com/azure/virtual-desktop/context-based-redirections-avd) |
| Drive redirection | Host pool RDP properties, Intune or Group Policy | Disabled unless required | **Status:** Generally available | [Supported RDP properties](https://learn.microsoft.com/azure/virtual-desktop/rdp-properties) |
| Printer redirection | Host pool RDP properties, Intune or Group Policy | Disabled or tightly scoped | **Status:** Generally available | [Supported RDP properties](https://learn.microsoft.com/azure/virtual-desktop/rdp-properties) |
| USB redirection | Host pool RDP properties, Intune or Group Policy | Disabled by default | **Status:** Generally available | [Peripheral redirection](https://learn.microsoft.com/azure/virtual-desktop/redirection-remote-desktop-protocol) |
| Trusted Launch | Azure VM configuration and image pipeline | Enabled | **Status:** Generally available | [What's new](https://learn.microsoft.com/azure/virtual-desktop/whats-new#july-2023) |
| Display Protection | Host pool configuration and supported endpoints | Track for high-risk desktop use cases | **Status:** Preview | [Display Protection](https://learn.microsoft.com/windows-365/enterprise/windows-cloud-display-protection) |
| Windows Cloud Keyboard Input Protection | Supported endpoint and session configuration | Track for sensitive input scenarios | **Status:** Preview | [Input protection](https://learn.microsoft.com/windows-365/enterprise/windows-cloud-input-protection) |
| Defender for Endpoint | Base image and security operations | Use non-persistent VDI onboarding package | **Status:** Generally available, documented without preview label | [Onboard non-persistent VDI](https://learn.microsoft.com/defender-endpoint/configure-endpoints-vdi) |
| FSLogix antivirus exclusions | Microsoft Defender Antivirus policy | Exclude documented FSLogix paths and processes | **Status:** Generally available, documented without preview label | [FSLogix prerequisites](https://learn.microsoft.com/fslogix/overview-prerequisites#configure-antivirus-file-and-folder-exclusions) |
| Private endpoints | Azure networking | Use where service private connectivity is required | **Status:** Generally available, documented without preview label | [Azure Private Link with Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/private-link-overview) |
| Intune security baselines | Intune Settings Catalog | Review and configure settings for multi-session | **Status:** Generally available for Windows Enterprise multi-session support | [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#security-baselines) |

## In this section

<div class="grid cards" markdown>

-   __[Session controls](session-controls.md)__

    ---

    Screen capture protection, watermarking, clipboard controls, context-based redirections and device redirection.

-   __[Session host hardening](host-hardening.md)__

    ---

    Trusted launch, Microsoft Defender for Endpoint, antivirus exclusions for FSLogix and Defender for Cloud.

-   __[Least-privilege administration](administration.md)__

    ---

    Using the built-in Desktop Virtualization roles to give each team only the access it needs.

</div>

## Common pitfalls

- Enabling screen capture protection or watermarking without testing client support.
- Enabling clipboard at the host pool layer and assuming Intune restrictions will always make it safe. Learn states the most restrictive setting wins, so test resultant behaviour [Clipboard redirection](https://learn.microsoft.com/azure/virtual-desktop/redirection-configure-clipboard).
- Forgetting that drive redirection can also affect clipboard file transfer. Learn says disabling drive redirection prevents file transfer using clipboard, while text and images are not affected [Clipboard redirection](https://learn.microsoft.com/azure/virtual-desktop/redirection-configure-clipboard).
- Applying broad **Contributor** rights to support staff instead of Azure Virtual Desktop built-in roles.
- Treating non-persistent hosts like long-lived servers for patching and Defender onboarding. The North Star uses image-based updates and non-persistent VDI onboarding.

## Microsoft Learn

- [Security recommendations for Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/security-recommendations)
- [Enable screen capture protection in Azure Virtual Desktop and Windows 365](https://learn.microsoft.com/azure/virtual-desktop/screen-capture-protection)
- [Watermarking in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/watermarking)
- [Configure clipboard redirection over the Remote Desktop Protocol](https://learn.microsoft.com/azure/virtual-desktop/redirection-configure-clipboard)
- [Configure the clipboard transfer direction and data types that can be copied in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/clipboard-transfer-direction-data-types)
- [Peripheral and resource redirection over the Remote Desktop Protocol](https://learn.microsoft.com/azure/virtual-desktop/redirection-remote-desktop-protocol)
- [Supported RDP properties](https://learn.microsoft.com/azure/virtual-desktop/rdp-properties)
- [Trusted Launch for Azure virtual machines](https://learn.microsoft.com/azure/virtual-machines/trusted-launch)
- [Onboard non-persistent VDI devices to Microsoft Defender for Endpoint](https://learn.microsoft.com/defender-endpoint/configure-endpoints-vdi)
- [Built-in Azure RBAC roles for Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/rbac)
- [Azure Private Link with Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/private-link-overview)
