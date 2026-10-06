---
title: Legacy application authentication
description: What works and what doesn't for legacy applications on Microsoft Entra joined session hosts, including NTLM and machine authentication.
---

# Legacy application authentication

## Application authentication considerations

Microsoft Entra joined session hosts change the machine identity. User authentication to AD DS-backed resources can still work where the user has line of sight to a domain controller and the protocol supports user Kerberos or NTLM. Learn states that AD DS and line of sight are needed to access on-premises resources from Microsoft Entra joined VMs [Microsoft Entra joined session hosts](https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts#accessing-on-premises-resources).

The key design boundary is machine authentication. Learn says Microsoft Entra joined devices do not support on-premises applications that rely on machine authentication [Device join plan](https://learn.microsoft.com/entra/identity/devices/device-join-plan#understand-considerations-for-applications-and-resources). Those applications belong in the hybrid-joined stepping-stone pool until remediated.

NTLM needs specific attention. Windows 11 version 24H2 removes NTLMv1, and Windows Server 2025 removes NTLMv1, according to Microsoft Learn [Removed features in Windows client](https://learn.microsoft.com/windows/whats-new/removed-features). NTLMv2 is not the same risk or compatibility problem as NTLMv1, but NTLM as a whole is deprecated in Windows client docs, so new design should prefer Kerberos or modern authentication where possible [Deprecated features for Windows client](https://learn.microsoft.com/windows/whats-new/deprecated-features).

Applications that authenticate users themselves need attention too. Learn says they must use the implicit UPN or the NT4 syntax with the domain FQDN, for example **user@contoso.corp.com** or **contoso.corp.com\user**. If an application uses the NetBIOS or legacy name, such as **contoso\user**, it gets NT error **STATUS_BAD_VALIDATION_CLASS - 0xc00000a7** or Windows error **ERROR_BAD_VALIDATION_CLASS - 1348**, and Learn notes this "happens even if you can resolve the legacy domain name" ([How SSO to on-premises resources works on Microsoft Entra joined devices](https://learn.microsoft.com/entra/identity/devices/device-sso-to-on-premises-resources#what-you-should-know)).

!!! warning "Test every legacy application"
    The NetBIOS name format is easy to miss, because the same application works on domain-joined hosts. Include it in application testing, and route any application that can't change to the hybrid joined stepping-stone pool until it's fixed.

---

Part of [Identity and access](index.md).
