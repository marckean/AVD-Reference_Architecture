# Intune policy examples for pooled Azure Virtual Desktop

This folder contains example Microsoft Intune Settings Catalog policies for a pooled Azure Virtual Desktop baseline. They are intended for an organisation that has no existing Intune policies for session hosts and wants a reviewable starting point.

The examples are generic and use Contoso values. Review and adapt every value before deployment.

## What is included

| File | Purpose |
| --- | --- |
| [policies/avd-identity-and-fslogix.json](policies/avd-identity-and-fslogix.json) | Enables Microsoft Entra Kerberos ticket retrieval for Azure Files and configures the North Star FSLogix profile container defaults. |
| [policies/avd-defender-fslogix-exclusions.json](policies/avd-defender-fslogix-exclusions.json) | Adds Microsoft Defender Antivirus exclusions for FSLogix binaries, cache folders, temporary VHD or VHDX files and the profile share. |
| [policies/avd-session-redirection.json](policies/avd-session-redirection.json) | Configures Azure Virtual Desktop clipboard transfer direction to allow plain text only in each direction, while leaving the full clipboard block disabled. |
| [policies/avd-windows-laps.json](policies/avd-windows-laps.json) | Configures Windows LAPS to back up the managed local administrator password to Microsoft Entra ID, plus a small set of password settings to review. |
| [Deploy-IntunePolicy.ps1](Deploy-IntunePolicy.ps1) | Validates the JSON files, resolves Settings Catalog definitions from the tenant through Microsoft Graph beta, verifies choices and creates the policies. |
| [tests/Invoke-PolicyOfflineValidation.Tests.ps1](tests/Invoke-PolicyOfflineValidation.Tests.ps1) | Pester 5 tests for offline validation and style checks. |

## Why settings are resolved at deployment time

Settings Catalog policies use Microsoft Graph setting definition IDs and, for choice settings, option item IDs. These IDs can vary and should not be invented. The JSON files therefore record the human settings picker path, CSP or registry path, intended value, why the value is set and the Microsoft Learn source. The deployment script then queries Microsoft Graph beta **/deviceManagement/configurationSettings**, resolves each setting definition in the tenant, verifies the selected choice option exists and stops before creating anything if a setting cannot be resolved.

This is safer than copying IDs from another tenant or from memory. It also means the files remain readable for review.

Microsoft documents the Microsoft Graph beta **deviceManagementConfigurationPolicy** resource type and states that Intune beta APIs are subject to more frequent change and recommends v1.0 where possible. The Settings Catalog APIs used here are beta, so run **-WhatIf** first and test in a non-production tenant or a small test device group before production use.

## Review and adapt the policy files

Before deployment:

1. Replace Contoso paths such as **\\\\stcontosofslogix01.file.core.windows.net\\profiles** with the organisation's Azure Files shares.
2. Decide whether to keep **DeleteLocalProfileWhenVHDShouldApply** at **0** for the first deployment. The site recommends setting it to **1** only after migration testing because Learn warns it permanently deletes the matching local profile.
3. Review FSLogix **SizeInMBs** per persona. Learn documents **30000** MB as the default and notes that existing containers can be expanded but not shrunk by lowering the setting.
4. Review Defender exclusions with the security team. Learn says FSLogix exclusions should be applied in all layers of security, including endpoint AV, network scanning and DLP.
5. Review clipboard direction with security and user experience owners. The example allows plain text only in both directions.
6. Review Windows LAPS values with operations. The example backs up to Microsoft Entra ID and uses a 30 day age and 16 character password length.

## Deploy

Requirements:

- PowerShell 7.2 or later.
- Microsoft Graph PowerShell Authentication module with **Connect-MgGraph** and **Invoke-MgGraphRequest** available.
- A signed-in administrator with permission to create Intune configuration policies.
- A tenant with an active Intune licence. Microsoft Graph Intune API pages state that the tenant requires an active Intune licence.
- Delegated Graph scope **DeviceManagementConfiguration.ReadWrite.All** for deployment. For read-only online resolution only, **DeviceManagementConfiguration.Read.All** is the least privileged read scope documented for listing setting definitions, but this script uses the read-write scope when it creates policies.

Offline validation only:

```powershell
pwsh -NoProfile -File .\tools\intune\Deploy-IntunePolicy.ps1 -OfflineValidationOnly
```

Online validation and deployment preview:

```powershell
pwsh -NoProfile -File .\tools\intune\Deploy-IntunePolicy.ps1 -WhatIf -Verbose
```

Create policies unassigned:

```powershell
pwsh -NoProfile -File .\tools\intune\Deploy-IntunePolicy.ps1 -Verbose
```

Create policies and assign them to a test device group:

```powershell
pwsh -NoProfile -File .\tools\intune\Deploy-IntunePolicy.ps1 -AssignToGroupId '00000000-0000-0000-0000-000000000000' -Verbose
```

The default is unassigned. This is intentional. Review the created policies in the Intune admin centre, then assign them to a device group that contains only test session hosts.

## Targeting

Follow the site targeting model:

- Use Microsoft Entra device groups for session hosts.
- Use device-scoped settings for host configuration.
- When creating or assigning policies for Windows Enterprise multi-session, use an Intune Settings Catalog filter with **OS edition == Enterprise multi-session**. Microsoft Learn documents this filter when creating Windows Enterprise multi-session configuration profiles.
- Do not assign device-based configuration to users or user-based configuration to devices. Learn says wrong scope can report **Error** or **Not applicable** for Windows Enterprise multi-session.

These examples contain only device-scoped settings and are intended for device groups.

## Roll back

The script creates one Intune configuration policy per JSON file. To roll back:

1. Remove assignments from the test group, or delete the created policies from the Intune admin centre.
2. Wait for policy refresh or restart test session hosts where the setting requires a restart.
3. Rebuild pooled ephemeral session hosts from the approved image if the host pool is disposable.
4. For FSLogix, do not assume deleting the policy deletes existing profile containers. Profile recovery and cleanup need an operational runbook.

If you adapt the script for automated rollback, use Microsoft Graph beta **DELETE /deviceManagement/configurationPolicies/{id}** only after confirming the policy ID and assignment state.

## AI assistance

Microsoft Learn describes **Microsoft Copilot in Intune** as capabilities powered by Microsoft Security Copilot that are embedded in the Microsoft Intune admin centre. The page says Copilot in Intune can help manage policies and settings, understand security posture and troubleshoot device issues. It also says Copilot in Intune is included with Security Copilot, uses Copilot security compute units, has no additional Intune-specific licence, honours existing Intune RBAC permissions and scope tags, and requires the Microsoft Intune plug-in source to be enabled in Security Copilot.

The Learn page reviewed for this repository does not label the embedded Copilot in Intune experience as preview. Treat availability and licensing as tenant-specific because Security Copilot setup, roles, sources and capacity must be configured before use.

Useful AI-assisted tasks:

- Explain a setting and summarize its Learn source.
- Compare an existing Intune policy with one of these JSON files.
- Draft a new policy file in the same format.
- Identify settings that have no Learn source or no resolver metadata.

Tasks that must stay with people:

- Approving security posture and data movement controls.
- Selecting the correct device groups and filters.
- Reviewing tenant-specific settings catalog resolution results.
- Testing in a real host pool before production rollout.
- Deciding rollback and operational recovery.

## Microsoft Learn references

- Windows Enterprise multi-session remote desktops with Intune: https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session
- Azure Files Microsoft Entra Kerberos and **CloudKerberosTicketRetrievalEnabled**: https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable
- FSLogix configuration setting reference: https://learn.microsoft.com/fslogix/reference-configuration-settings
- FSLogix prerequisites and antivirus exclusions: https://learn.microsoft.com/fslogix/overview-prerequisites
- Microsoft Defender Antivirus exclusions Policy CSP: https://learn.microsoft.com/windows/client-management/mdm/policy-csp-defender
- Azure Virtual Desktop clipboard transfer direction: https://learn.microsoft.com/azure/virtual-desktop/clipboard-transfer-direction-data-types
- Clipboard redirection: https://learn.microsoft.com/azure/virtual-desktop/redirection-configure-clipboard
- Windows LAPS CSP: https://learn.microsoft.com/windows/client-management/mdm/laps-csp
- Windows LAPS with Microsoft Entra ID: https://learn.microsoft.com/windows-server/identity/laps/laps-scenarios-azure-active-directory
- Microsoft Graph beta **deviceManagementConfigurationPolicy**: https://learn.microsoft.com/graph/api/resources/intune-deviceconfigv2-devicemanagementconfigurationpolicy
- Create Microsoft Graph beta **deviceManagementConfigurationPolicy**: https://learn.microsoft.com/graph/api/intune-deviceconfigv2-devicemanagementconfigurationpolicy-create
- List Microsoft Graph beta **deviceManagementConfigurationSettingDefinitions**: https://learn.microsoft.com/graph/api/intune-deviceconfigv2-devicemanagementconfigurationsettingdefinition-list
- Microsoft Graph PowerShell **Connect-MgGraph**: https://learn.microsoft.com/powershell/module/microsoft.graph.authentication/connect-mggraph
- Microsoft Graph PowerShell **Invoke-MgGraphRequest**: https://learn.microsoft.com/powershell/module/microsoft.graph.authentication/invoke-mggraphrequest
- Microsoft Copilot in Intune: https://learn.microsoft.com/intune/copilot/
