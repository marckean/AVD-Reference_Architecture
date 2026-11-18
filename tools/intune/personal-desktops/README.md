# Intune starter set for Azure Virtual Desktop personal desktops

A reviewable starting point for Microsoft Entra joined personal desktops (one user per session host) when an organisation has no Intune policies for virtual desktops yet. The examples are generic and use Contoso values. Review and adapt every value before use.

The pooled host examples in [`../policies`](../policies) and [`../Deploy-IntunePolicy.ps1`](../Deploy-IntunePolicy.ps1) are separate. Use this folder for personal desktops, which also need compliance, update rings, apps and trusted certificates.

## What's included

| File | Kind | What it sets |
|---|---|---|
| `policies/10-windows-compliance.json` | Compliance policy | Windows 11 24H2 or later (10.0.26100) and an antivirus registered with Windows Security Center. Third-party antivirus counts. Noncompliant straight away. |
| `policies/20-windows-laps.json` | Settings catalog | Windows LAPS: back up to Microsoft Entra ID, 30-day age, complexity 4, length 16, reset and sign out 8 hours after use. |
| `policies/30-session-clipboard.json` | Settings catalog | Clipboard limited to plain text in each direction (device scope). |
| `policies/31-session-time-limits.json` + `scripts/Set-SessionTimeLimits.ps1` | Platform script | Idle sessions disconnect after 90 minutes; disconnected sessions sign out after 180 minutes. Set the minutes with variables. |
| `policies/32-screen-capture-protection.json` | Settings catalog, **optional** | Screen capture protection (block on client). Off unless added. |
| `policies/40-update-ring.json` | Update ring | Quality updates outside active hours (7 am to 7 pm), 3-day deadline, 2-day grace, feature updates deferred 30 days, drivers excluded. |
| `policies/50-microsoft-365-apps.json` | App | Microsoft 365 Apps, 64-bit, Monthly Enterprise Channel, without Teams, Access, Publisher and Skype for Business. |
| `policies/60-trusted-certificates.json` | Trusted certificate | One profile per root or issuing CA `.cer`, so MSIX packages signed by your CA install. Only when paths are set. |

Each file records the CSP path or Graph properties, the value, why it's set, the admin center click path and the Microsoft Learn source.

Session time limits use a platform script because the Administrative Template only offers fixed choices (1 hour, 2 hours, 3 hours and so on), so 90 minutes isn't possible there. The script writes the same computer policy values, `MaxIdleTime` and `MaxDisconnectionTime` in milliseconds ([Learn](https://learn.microsoft.com/troubleshoot/windows-server/remote/troubleshoot-unexpected-rds-session-locks-or-disconnections)).

## Why settings are resolved at run time

Settings catalog policies use setting definition IDs and option IDs, which must not be invented. `Deploy-PersonalDesktopIntune.ps1` reads each definition from the tenant: by ID first, then by CSP path (`baseUri` plus `offsetUri`), then by display name. It takes child settings from the chosen option's own dependency list, and checks values against the definition's options, minimum and maximum. If anything doesn't resolve, it stops before creating anything and prints the admin center click path instead.

## Prerequisites

- **Roles.** To validate: Intune Read Only Operator is enough. To create: Policy and Profile Manager or Intune Administrator, plus Application Manager for Microsoft 365 Apps ([built-in roles](https://learn.microsoft.com/intune/fundamentals/role-based-access-control/ref-built-in-roles)).
- **Graph consent.** Microsoft Graph Command Line Tools needs admin consent for these scopes:
  - `DeviceManagementConfiguration.Read.All` or `DeviceManagementConfiguration.ReadWrite.All`;
  - `DeviceManagementApps.Read.All` or `DeviceManagementApps.ReadWrite.All`;
  - `Group.Read.All` when you assign.

  In Cloud Shell the script uses device code sign-in. If Conditional Access blocks device code flow, use the portal steps below.
- **Tenant settings.** The script doesn't change these:
  - **Intune automatic enrolment.** The MDM user scope must cover the users who sign in to the hosts.
  - **Microsoft Entra LAPS** turned on: Entra ID > Devices > Device settings.
  - **Noncompliance default.** Decide how devices with no compliance policy are marked.
- **A device group.** For example, a dynamic Entra device group with the rule `(device.displayName -startsWith "contosodd")`. Its prefix is the host pool's `$WorkloadPrefix`.

## Run it

Validate first. Validation only reads Intune and needs only read scopes:

```powershell
$PolicyNamePrefix = 'Contoso AVD personal - '
$ValidateOnly     = $true
irm https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/tools/intune/personal-desktops/Deploy-PersonalDesktopIntune.ps1 | iex
```

Then create the policies. By default they're unassigned, so you can review them in the admin center:

```powershell
$ValidateOnly = $false
irm https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/tools/intune/personal-desktops/Deploy-PersonalDesktopIntune.ps1 | iex
```

Optional variables:

| Variable | Default | Purpose |
|---|---|---|
| `$AssignToGroupId` or `$AssignToGroupName` | none | Assign to an Entra device group. Only objects with no assignments yet are assigned, so existing assignments are never replaced. |
| `$AssignmentFilterName` | none | Include filter for the assignments. Not applied to platform scripts. |
| `$AppInstallIntent` | `required` | Microsoft 365 Apps assignment intent. |
| `$AddOptionalPolicies` | none | For example `@('32-screen-capture-protection')`. |
| `$IncludePolicies` / `$ExcludePolicies` | all / none | File names or number prefixes, for example `@('20', '30')`. |
| `$SessionIdleLimitMinutes` / `$SessionDisconnectedLimitMinutes` | 90 / 180 | Session time limits. |
| `$TrustedRootCertificatePaths` / `$TrustedIntermediateCertificatePaths` | none | Public `.cer` files. In Cloud Shell, upload them first (Manage files > Upload). |
| `$IntunePolicyFolder` | GitHub | Use a local copy of this folder instead of GitHub. |
| `$TenantId` | Azure context | Tenant to sign in to. |

Running it again is safe. Objects are matched by name and existing ones are left as they are.

## Portal steps (no script)

Each policy file's `portalPath` has the click path. In short:

1. **Compliance.** Devices > Compliance > Create policy > Windows 10 and later.
   - System Security: Antivirus = Require.
   - Device Properties: Minimum OS version = 10.0.26100.
   - Actions: Mark device noncompliant after 0 days.
2. **Windows LAPS.** Endpoint security > Account protection > Create policy > Windows > Local admin password solution (Windows LAPS).
   - Backup Directory = Microsoft Entra ID only.
   - Password Age Days = 30.
   - Password Complexity = large and small letters, numbers and special characters.
   - Password Length = 16.
   - Post-authentication actions = reset the password and sign out.
   - Reset delay = 8.
3. **Clipboard.** Devices > Configuration > Create > New policy > Windows 10 and later > Settings catalog.
   - Go to Administrative templates > Windows Components > Remote Desktop Services > Remote Desktop Session Host > Device and Resource Redirection.
   - Restrict clipboard transfer from server to client = Enabled, Allow plain text.
   - Restrict clipboard transfer from client to server = Enabled, Allow plain text.
   - Use the device settings, not the (User) ones.
4. **Session time limits.** Devices > Scripts and remediations > Platform scripts > Add > Windows 10 and later.
   - Upload `scripts/Set-SessionTimeLimits.ps1` after setting the minutes at the top.
   - Run as system (logged-on credentials = No), signature check = No, 64-bit = Yes.
5. **Screen capture protection (optional).** Settings catalog.
   - Go to Administrative templates > Windows Components > Remote Desktop Services > Remote Desktop Session Host > Azure Virtual Desktop.
   - Enable screen capture protection = Enabled.
   - Screen Capture Protection Options (Device): off = block on client.
6. **Update ring.** Devices > Windows updates > Update rings > Create profile, with the values in `40-update-ring.json`.
7. **Microsoft 365 Apps.** Apps > Windows > Add > Microsoft 365 Apps (Windows 10 and later).
   - Settings: 64-bit, Monthly Enterprise Channel, shared computer activation = No.
   - Exclude Access, Publisher, Skype for Business and Teams.
8. **Trusted certificates.** Devices > Configuration > Create > New policy > Windows 10 and later > Templates > Trusted certificate.
   - One profile per `.cer`.
   - Destination store: Computer certificate store - Root, or - Intermediate.

Assign each one to the device group. Clipboard and screen capture settings need a host restart. Time limits apply from the next sign-in.

## Check the result on the hosts

Run `deploy/personal/Test-PersonalDesktopHosts.ps1` from Cloud Shell. It's read-only and uses Run Command. On each host it reports:
- the Intune enrolment and the Intune Management Extension;
- the clipboard and time-limit policy values;
- the LAPS backup directory and the antivirus;
- Microsoft 365 Apps and the Teams optimisation components.

## Roll back

- Remove the group from each assignment, or delete the objects in the admin center. They're all named with `$PolicyNamePrefix`.
- Deleting the platform script doesn't remove the registry values it wrote. To revert, delete `MaxIdleTime` and `MaxDisconnectionTime` from `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services` on the hosts.
- Removing the LAPS policy stops rotation. The last password stays in Entra ID until the device is deleted.

## Microsoft Learn

- Clipboard transfer direction: https://learn.microsoft.com/azure/virtual-desktop/clipboard-transfer-direction-data-types
- RemoteDesktopServices Policy CSP: https://learn.microsoft.com/windows/client-management/mdm/policy-csp-remotedesktopservices
- Screen capture protection: https://learn.microsoft.com/azure/virtual-desktop/screen-capture-protection
- Windows LAPS CSP: https://learn.microsoft.com/windows/client-management/mdm/laps-csp
- Windows LAPS with Microsoft Entra ID: https://learn.microsoft.com/entra/identity/devices/howto-manage-local-admin-passwords
- Windows compliance settings: https://learn.microsoft.com/intune/device-security/compliance/ref-windows-settings
- Settings catalog definitions (Graph beta): https://learn.microsoft.com/graph/api/intune-deviceconfigv2-devicemanagementconfigurationsettingdefinition-list?view=graph-rest-beta
- Update ring (Graph beta): https://learn.microsoft.com/graph/api/intune-deviceconfig-windowsupdateforbusinessconfiguration-create?view=graph-rest-beta
- Microsoft 365 Apps (Graph beta): https://learn.microsoft.com/graph/api/intune-apps-officesuiteapp-create?view=graph-rest-beta
- Trusted certificate (Graph beta): https://learn.microsoft.com/graph/api/intune-deviceconfig-windows81trustedrootcertificate-create?view=graph-rest-beta
- Platform scripts (Graph beta): https://learn.microsoft.com/graph/api/intune-shared-devicemanagementscript-create?view=graph-rest-beta
- Intune and Azure Virtual Desktop: https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session
