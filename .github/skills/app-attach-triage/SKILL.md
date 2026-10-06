---
name: app-attach-triage
description: Triage an application inventory into App Attach delivery routes and migration waves for Azure Virtual Desktop. Use when someone has output from tools/app-attach Get-AppVPackageInventory.ps1, Get-ImageApplicationInventory.ps1 or Invoke-ApplicationTriage.ps1 (CSV or JSON) and wants a route for each application, a wave plan, or questions for application owners.
argument-hint: "[path to an inventory or triage CSV or JSON file]"
---

# Triage applications for App Attach

Turn an application inventory into a plan the team can act on. The inventory comes from the scripts in [tools/app-attach](../../../tools/app-attach/README.md). The workflow is described on the site's [App Attach fast track](../../../docs/accelerators/app-attach-fast-track.md) page.

## Inputs you may be given

- **App-V inventory** from `Get-AppVPackageInventory.ps1`. One row per package, with `PackageName`, `Version`, `Publisher`, `ApplicationCount`, the integration points (`Shortcuts`, `FileTypeAssociations`, `UrlProtocols`, `Com`, `Services`, `ShellExtensions`, `Fonts`, `EnvironmentVariables`), and the dynamic configuration flags (`HasDeploymentConfig`, `DeploymentConfigContainsScripts`, `HasUserConfig`, `UserConfigContainsScripts`).
- **Golden image inventory** from `Get-ImageApplicationInventory.ps1 -Mode Online|Offline`. Rows have an `InventoryType` (uninstall entries, provisioned packages, App-V packages, services, drivers) plus `DisplayName`, `DisplayVersion`, `Publisher`, `InstallLocation`, `WindowsInstaller`, `SystemComponent`, `ParentKeyName` and `AssociatedApplication`.
- **Triage output** from `Invoke-ApplicationTriage.ps1 -InputPath <inventory> -RulesPath tools/app-attach/triage-rules.json`, with `Name`, `Publisher`, `Version`, `Path`, `SourceType`, `Recommendation` and `Reason`.

If you only have an inventory, suggest running `Invoke-ApplicationTriage.ps1` first, and offer to tune [triage-rules.json](../../../tools/app-attach/triage-rules.json) for this estate.

## Routes

Use exactly these route names. They match the triage rules.

| Route | Meaning |
| --- | --- |
| `KeepInBaseImage` | Runtimes, redistributables, security and management agents, Microsoft 365 Apps |
| `AppAttachAppV` | An App-V package exists and App Attach can use it as it is |
| `AppAttachMsix` | Repackage from source as MSIX, sign it and build a CimFS image |
| `ReviewDriversOrServices` | Has a driver or service. MSIX doesn't support Windows drivers, so a person decides |
| `LegacyPool` | Needs Active Directory machine authentication or similar. Only a person sets this route |
| `Retire` | Unused, duplicated or out of support. Only a person sets this route |

## Steps

1. Load the file. Report counts by route and by source type, and flag rows with no publisher, no version or no owner.
2. Remove noise: system components, updates that belong to a parent (`ParentKeyName`), and the same application seen in both the 64-bit and 32-bit views.
3. Propose waves:
   - **Wave 1:** `AppAttachAppV` packages with no dynamic configuration scripts, no services and few integration points. They prove the platform.
   - **Wave 2:** the remaining App-V packages and the simplest `AppAttachMsix` conversions.
   - **Wave 3:** anything with COM, shell extensions, services or scripts. Test these first, with a named application owner.
   - **Not App Attach:** `KeepInBaseImage`, `ReviewDriversOrServices`, `LegacyPool` and `Retire`, each with the reason.
4. For each wave, list the questions for application owners: who tests, which test group, licensing, how often the application updates, and any dependencies.
5. For wave 1, draft the onboarding CSV for `Add-AppAttachApplication.ps1 -CsvPath`, with the columns `ResourceGroupName`, `Location`, `HostPoolName`, `PackagePath`, `Name`, `DisplayName`, `SubscriptionId`, `PackageFullName`, `HostPoolResourceId` and `GroupObjectId`. Use placeholders for values you don't know.
6. Finish with: a summary table, the wave plan, open questions, and what you couldn't decide.

## Rules

- Never say an application works with App Attach. Say what to test and why.
- Ground every support statement in Microsoft Learn:
  - [App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)
  - [App-V support policy](https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy)
  - [Prepare to package a desktop application](https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare)
- People decide `LegacyPool` and `Retire`. You can suggest them, clearly marked as suggestions.
- Don't copy organisation names, user names or server names from the inventory into anything that leaves the conversation.
