---
name: intune-policy-examples
description: Review, adapt, write or deploy the Intune settings catalog policy examples in tools/intune for Microsoft Entra joined Windows 11 Enterprise multi-session Azure Virtual Desktop session hosts. Use when someone asks about the policy files, wants to change a setting or value, add a new policy file in the same format, validate the files, or deploy them with Deploy-IntunePolicy.ps1.
argument-hint: "[policy file, setting, or what you want to change]"
---

# Intune policy examples for AVD session hosts

The examples live in [tools/intune/policies](../../../tools/intune/policies/) and are explained in the [tools/intune README](../../../tools/intune/README.md). The site's [Required policies](../../../docs/intune/policies.md) page says why each setting matters.

## The policy file format

Each file is one policy:

- top level: `schemaVersion`, `name`, `description`, `platforms`, `technologies`, `assignmentDefault`, `settings`
- each setting: `key`, `settingPickerPath` (where it is in the Intune settings picker), `scope` (device or user), `settingType`, `value`, `resolver` (how the deployment script finds the setting in the tenant), `why`, and `learnLinks`

## Golden rule: never invent settings catalog IDs

Settings catalog policies reference `settingDefinitionId` values. The files deliberately don't hardcode them. `Deploy-IntunePolicy.ps1` resolves each setting and option against the tenant's settings catalog through Microsoft Graph, and stops with the settings picker path if it can't. When you add or change a setting, describe it the same way: the settings picker path, the CSP or registry path from Learn, the value, the scope and the Learn link. Don't paste an ID from memory.

## Steps

1. **Explain or change a setting.** Find it on Microsoft Learn first, for example in the Policy CSP, FSLogix configuration settings or the Azure Virtual Desktop articles. Quote the setting name and allowed values exactly.
2. **Validate offline:** `./tools/intune/Deploy-IntunePolicy.ps1 -OfflineValidationOnly`. This checks the files without connecting.
3. **Preview against a tenant:** `./tools/intune/Deploy-IntunePolicy.ps1 -WhatIf`. It connects with least-privilege scopes, resolves every setting and creates nothing.
4. **Deploy unassigned,** review in the Intune admin center, then assign to a test device group with `-AssignToGroupId <group object ID>`.

## Targeting

Session hosts are targeted with device groups and device-scoped settings, plus a filter on the operating system edition, as the site's [Enrolment and targeting](../../../docs/intune/targeting.md) page describes. Learn says settings catalog is the supported way to configure Windows Enterprise multi-session ([Intune and multi-session](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session)).

## Rules

- Ground every setting, value and limit in Microsoft Learn, and cite the link.
- Never deploy to production without `-WhatIf` first and a test group.
- Copilot in Intune, which is included with Security Copilot ([Microsoft Copilot in Intune](https://learn.microsoft.com/intune/copilot/)), can explain settings inside the Intune admin center. Suggest it as a cross-check, not a replacement for testing.
