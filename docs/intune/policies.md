---
title: Required policies
description: The Intune policies an Entra joined multi-session host needs, with exact settings and values, plus Teams and OneDrive.
---

# Required policies

| Policy area | Setting | Value | Why | Learn link |
| --- | --- | --- | --- | --- |
| Microsoft Entra Kerberos for Azure Files | **Kerberos/CloudKerberosTicketRetrievalEnabled** | **1** | Allows Microsoft Entra joined hosts to retrieve Microsoft Entra Kerberos tickets for Azure Files FSLogix profiles. Learn says use Settings Catalog instead of OMA-URI for AVD multi-session. Device-scoped. | [Azure Files Microsoft Entra Kerberos](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable#configure-the-clients-to-retrieve-kerberos-tickets) |
| FSLogix profiles | **Enabled** under **SOFTWARE\FSLogix\Profiles** | **1** | Enables FSLogix profile containers. Device-scoped. | [FSLogix configuration settings](https://learn.microsoft.com/fslogix/reference-configuration-settings#enabled) |
| FSLogix profile path | **VHDLocations** under **SOFTWARE\FSLogix\Profiles** | `\\<storage-account>.file.core.windows.net\<share>` | Points FSLogix at sharded Azure Files shares. Device-scoped. | [FSLogix VHDLocations](https://learn.microsoft.com/fslogix/reference-configuration-settings#vhdlocations) |
| FSLogix profile cleanup | **DeleteLocalProfileWhenVHDShouldApply** | **1** only after migration testing | Deletes a matching local profile when FSLogix should apply. Learn warns this permanently deletes the local profile. Device-scoped. | [FSLogix DeleteLocalProfileWhenVHDShouldApply](https://learn.microsoft.com/fslogix/reference-configuration-settings#deletelocalprofilewhenvhdshouldapply) |
| FSLogix container format | **VolumeType** | **vhdx** | Uses VHDX for newly created profile containers. Device-scoped. | [FSLogix VolumeType](https://learn.microsoft.com/fslogix/reference-configuration-settings#volumetype) |
| FSLogix identity roaming | **RoamIdentity** | **0** | Learn says the default is **0** and FSLogix does not roam identity data by default. Keep the default for Intune-managed multi-session hosts. Device-scoped. | [FSLogix RoamIdentity](https://learn.microsoft.com/fslogix/reference-configuration-settings#roamidentity) |
| Microsoft Defender Antivirus | FSLogix file and folder exclusions from Learn | Configure documented exclusions | Reduces profile container lock and performance issues. Device-scoped. | [FSLogix antivirus exclusions](https://learn.microsoft.com/fslogix/overview-prerequisites#configure-antivirus-file-and-folder-exclusions) |
| Clipboard direction | **Restrict clipboard transfer from server to client** and **Restrict clipboard transfer from client to server** | **Enabled**, then choose **Allow plain text** or stricter | Limits data exfiltration and inbound file copy. Device-scoped for pooled hosts. | [Clipboard transfer direction](https://learn.microsoft.com/azure/virtual-desktop/clipboard-transfer-direction-data-types) |
| Clipboard on or off | **Do not allow Clipboard redirection** | **Enabled** where clipboard is not required | Blocks clipboard redirection at the session host. Device-scoped. | [Clipboard redirection](https://learn.microsoft.com/azure/virtual-desktop/redirection-configure-clipboard) |
| Teams media optimisation | **IsWVDEnvironment** registry value | **1** for classic Teams path where applicable | Learn documents **IsWVDEnvironment** as part of preparing Teams on AVD. Device-scoped. | [Use Microsoft Teams on Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/teams-on-avd) |
| Teams media devices | RDP properties **audiocapturemode:i:1** and **camerastoredirect:s:*** where needed | Enable only for personas needing microphone and camera | Learn says media optimisation does not require device redirections, but documents these RDP properties when microphone and camera redirection are required. Host pool setting. | [Use Microsoft Teams on Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/teams-on-avd) |
| OneDrive silent sign-in | **Silently sign in users to the OneDrive sync app with their Windows credentials** | Enabled where OneDrive is used | OneDrive policy is documented for Group Policy and Intune administrative templates. User-scoped or device-scoped according to policy applicability. | [OneDrive policies](https://learn.microsoft.com/sharepoint/use-group-policy) |
| OneDrive Known Folder Move | **Silently move Windows known folders to OneDrive** | Enabled only for personas where known folders are intended to roam through OneDrive | Learn documents the policy and rollout limits for existing devices. User-scoped policy. | [Redirect known folders](https://learn.microsoft.com/sharepoint/redirect-known-folders) |
| Windows LAPS | Windows LAPS policy to back up passwords to Microsoft Entra ID | Enabled for local administrator account | Provides managed local admin password recovery for Entra joined devices. Device-scoped. | [Windows LAPS with Microsoft Entra ID](https://learn.microsoft.com/windows-server/identity/laps/laps-scenarios-azure-active-directory) |
| RDP Shortpath management | Centralised RDP Shortpath policies in Intune or Group Policy | Configure managed, Public/STUN and Public/TURN transport modes to match the network design | Centralised RDP Shortpath management through Intune and Group Policy is generally available as of January 2026. Device-scoped. | [What's new in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/whats-new#january-2026) |
| Security baseline | Windows security baseline settings implemented through Settings Catalog | Review and configure | Learn says security baselines are available for Windows Enterprise multi-session and recommends configuring settings in Settings Catalog. Device-scoped. | [Windows Enterprise multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#security-baselines) |
| Quality update controls | Settings Catalog **Windows Update for Business** settings such as **Active Hours Start**, **Active Hours End**, **Defer Quality Updates Period (Days)** | Use only for exceptions or persistent hosts | Pooled ephemeral hosts should be updated through image rollout, but Learn documents supported Settings Catalog quality update settings. Device-scoped. | [Windows Update client policies](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#windows-update-client-policies) |

!!! note "FSLogix policy format"
    Microsoft Learn documents FSLogix settings as registry values. In Intune, implement them through Settings Catalog where the FSLogix ADMX settings are available, or through a device-scoped script or custom policy only when the setting is not exposed in Settings Catalog. Do not use OMA-URI for **CloudKerberosTicketRetrievalEnabled** on AVD multi-session, because Learn explicitly says the OMA-URI method does not work on Azure Virtual Desktop multisession devices [Azure Files Microsoft Entra Kerberos](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable#configure-the-clients-to-retrieve-kerberos-tickets).

## Teams and OneDrive

Teams on Azure Virtual Desktop supports chat and collaboration. With media optimisations, Teams supports calling and meeting functionality by redirecting media to the local device when using Windows App or the Remote Desktop client on a supported platform [Use Microsoft Teams on Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/teams-on-avd).

For OneDrive, Learn documents policies including **Silently sign in users to the OneDrive sync app with their Windows credentials**, **Prompt users to move Windows known folders to OneDrive**, **Silently move Windows known folders to OneDrive**, and **Prevent users from turning off Known Folder Move** [OneDrive policies](https://learn.microsoft.com/sharepoint/use-group-policy), [Redirect known folders](https://learn.microsoft.com/sharepoint/redirect-known-folders).

!!! warning "Profile design first"
    Do not use OneDrive Known Folder Move as a substitute for FSLogix profile containers. FSLogix carries the Windows profile for pooled hosts. OneDrive synchronises user files where that is the user experience standard. Keep the responsibilities separate.

---

Part of [Intune](index.md).
