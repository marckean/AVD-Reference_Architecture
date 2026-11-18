# Personal desktops (standard management)

This folder deploys Azure Virtual Desktop **personal desktops**: one user per session host, with a persistent managed OS disk. Use it for developer desktops and other 1:1 workloads.

The North Star template in `deploy/` builds **pooled** host pools with a session host configuration. Learn says that approach *"can be used with pooled host pools only"*, while *"standard management is available for pooled and personal host pools"* ([host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches)). So personal desktops use standard management: the session host VMs are deployed directly and registered with a registration token.

The deployment is generic. Examples use Contoso only.

## What gets deployed

| File | What it deploys |
|---|---|
| `hostpool.json` | Personal host pool (`Persistent` load balancing, `Automatic` or `Direct` assignment, Start VM on Connect), desktop application group, workspace, role assignments, diagnostics to Log Analytics, the AVD Insights data collection rule, a Key Vault (Azure RBAC) and an optional personal scaling plan. |
| `sessionhosts.json` | For each session host: a NIC in an existing subnet (no public IP), a Trusted launch VM with a managed OS disk, AD DS domain join **or** Microsoft Entra join (with optional Intune enrolment), AVD agent registration, the Azure Monitor Agent and the AVD Insights association. The local administrator password is stored in the Key Vault as `<vm-name>-localadmin`. |
| `Deploy-PersonalDesktopPilot.ps1` | Runs the pre-flight checks, both deployments, the registration token, display names and user assignment, then waits for the hosts to be **Available**. |
| `Test-PersonalDesktopHosts.ps1` | Read-only readiness check of every running session host through Run Command. It reports: <ul><li>join and Intune state, and the AVD agent;</li><li>the Teams optimisation parts;</li><li>Microsoft 365 Apps;</li><li>clipboard and session time-limit policy;</li><li>Windows LAPS and the antivirus;</li><li>developer tools.</li></ul> |

Names follow the workload prefix: `<prefix>-hp`, `<prefix>-dag`, `<prefix>-ws`, `<prefix>-law` (if created), `microsoft-avdi-<prefix>-<region>`, `<prefix>-kv-<suffix>`, and session hosts `<prefix>-0`, `<prefix>-1` and so on.

## Run it from Azure Cloud Shell

Set the variables, then pipe the script into `iex`. There's no param block, so the script reads the variables from your session:

```powershell
$SubscriptionId         = '00000000-0000-0000-0000-000000000000'
$ResourceGroupName      = 'rg-contoso-avd-devdesktops'
$ResourceGroupTags      = @{ Environment = 'Test'; Owner = 'avd-team' }
$SubnetId               = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-contoso-network/providers/Microsoft.Network/virtualNetworks/vnet-contoso/subnets/snet-avd'
$WorkloadPrefix         = 'contosodd'
$SessionHostCount       = 2
$VmSize                 = 'Standard_D4as_v5'
$JoinType               = 'EntraID'
$EnrollInIntune         = $true
$PilotUserPrincipalName = 'pilot.user@contoso.com'
$WorkspaceFriendlyName  = 'Contoso developer desktops'
$DesktopFriendlyName    = 'Developer desktop'
irm https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/personal/Deploy-PersonalDesktopPilot.ps1 | iex
```

For an **AD DS joined** pool, add the domain values. The script asks for the join account's password (`Read-Host -AsSecureString`) before anything is built:

```powershell
$JoinType           = 'ActiveDirectory'
$DomainName         = 'corp.contoso.com'
$DomainJoinOuPath   = 'OU=Desktops,DC=corp,DC=contoso,DC=com'
$DomainJoinUsername = 'svc-avdjoin@corp.contoso.com'
```

For a **gallery image**, set one of these. Otherwise a Marketplace image is used (`MicrosoftWindowsDesktop/windows-11/win11-24h2-ent` by default):

```powershell
$CustomImageResourceId    = '/subscriptions/.../galleries/gal_contoso/images/win11-dev/versions/1.0.0'   # an exact version
$GalleryImageDefinitionId = '/subscriptions/.../galleries/gal_contoso/images/win11-dev'                  # the latest published version
$GalleryName = 'gal_contoso'; $GalleryImageDefinitionName = 'win11-dev'                                 # found by name in the subscription
```

Run with `$ValidateOnly = $true` first for a what-if of both templates. It creates only the empty, tagged resource group if it is missing, because what-if needs one.

To run from local files instead of GitHub (for example after uploading them to Cloud Shell), set `$TemplateFolder` to the folder holding the two JSON files and run the script file.

### All variables

| Variable | Default | Notes |
|---|---|---|
| `SubscriptionId`, `ResourceGroupName`, `SubnetId`, `WorkloadPrefix` | (required) | `WorkloadPrefix`: 2 to 10 lowercase letters, digits or hyphens. |
| `Location` | `australiaeast` | An existing resource group's region wins. |
| `ResourceGroupTags` | `@{}` | Used when the script creates the resource group, and applied to every resource. |
| `SessionHostNamePrefix` | the workload prefix | Up to 11 characters, so `<prefix>-<n>` fits the 15-character computer name limit. |
| `SessionHostCount` | `2` | The total you want. Existing hosts are kept; only missing ones are created. |
| `VmSize`, `OsDiskType`, `OsDiskSizeGB`, `DiskControllerType`, `AvailabilityZone`, `VmTimeZone` | `Standard_D4as_v5`, `Premium_LRS`, image size, platform default, none, image default | Size and quota are checked before anything is built. |
| `JoinType` | `EntraID` | `EntraID` or `ActiveDirectory`. |
| `DomainName`, `DomainJoinOuPath`, `DomainJoinUsername` | | AD DS join only. |
| `EnrollInIntune` | `$true` | Entra join only: the `AADLoginForWindows` extension gets Intune's MDM ID. |
| `EntraSingleSignOn` | `$true` | Entra join: adds `enablerdsaadauth:i:1`; `$false` adds `targetisaadjoined:i:1` instead. |
| `HybridSingleSignOn` | `$false` | AD DS join: adds `enablerdsaadauth:i:1`. Needs Microsoft Entra hybrid joined hosts and a Kerberos server object. |
| `PilotUserPrincipalName`, `PilotUserPrincipalNames`, `PilotGroupObjectId`, `PilotGroupName` | | Get Desktop Virtualization User on the application group, and Virtual Machine User Login on the resource group for Entra join. |
| `AssignUsers` | `@()` | UPNs assigned in order to the session hosts (direct assignment). |
| `PersonalDesktopAssignmentType` | `Automatic` | `Automatic` or `Direct`. |
| `StartVMOnConnect` | `$true` | The Azure Virtual Desktop service principal gets Desktop Virtualization Power On Contributor on the resource group. |
| `WorkspaceFriendlyName`, `DesktopFriendlyName`, `ApplicationGroupFriendlyName`, `HostPoolFriendlyName` | derived from the prefix | What users see in Windows App. |
| `LogAnalyticsWorkspaceId` or `LogAnalyticsWorkspaceResourceGroupName` | create `<prefix>-law` | Reuse an existing workspace so several pools report together. |
| `EnableAvdInsights` | `$true` | Diagnostics, the data collection rule, the Azure Monitor Agent and the association. |
| `CreateKeyVault`, `KeyVaultNameSeed`, `KeyVaultPublicNetworkAccess` | `$true`, empty, `Enabled` | The signed-in user gets Key Vault Secrets Officer. Purge protection is on. |
| `EnableAutoscale`, `ScalingPlanTimeZone` | `$false`, `AUS Eastern Standard Time` | See "Power management" below. |
| `SupportGroupObjectId` | | Desktop Virtualization User Session Operator on the host pool. |
| `LocalAdminUsername` | `avdlocaladmin` | The password is generated, shown once and stored in the Key Vault. |
| `RdpProperties` | built from the join type | A full RDP property string overrides it. |
| `TemplateBaseUri`, `TemplateFolder` | this folder on GitHub | Where the two templates come from. |
| `AvdAgentPackageUrl` | auto | See "How the AVD agent is installed". |
| `ValidateOnly`, `WatchMinutes` | `$false`, `25` | |

## Check the hosts

After the hosts are Available, and again after Intune or Group Policy has applied, run the read-only check:

```powershell
$SubscriptionId    = '00000000-0000-0000-0000-000000000000'
$ResourceGroupName = 'rg-contoso-avd-personal'
irm https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/personal/Test-PersonalDesktopHosts.ps1 | iex
```

For Microsoft Entra joined personal desktops, the Intune starter set is in [`tools/intune/personal-desktops`](../../tools/intune/personal-desktops). The test apps, including the Teams media optimisation components, are in [`tools/intune/win32-test-apps`](../../tools/intune/win32-test-apps).

## How the AVD agent is installed

Standard-management session hosts are registered by the same **Azure Virtual Desktop configuration package** that the portal's host pool wizard uses, run by the PowerShell DSC extension. The package is downloaded by each VM from `wvdportalstorageblob.blob.core.windows.net`, which is on the [required FQDN list](https://learn.microsoft.com/azure/virtual-desktop/required-fqdn-endpoint) for session hosts.

The package's `AddSessionHost` parameters have changed over time, so the script:

1. picks the newest package it can reach (or `$AvdAgentPackageUrl`);
2. downloads it to Cloud Shell's temp folder and **reads** `Configuration.ps1` (it doesn't run it);
3. passes the registration token as `RegistrationInfoToken` or `RegistrationInfoTokenCredential`, whichever that version accepts, through `protectedSettings.configurationArguments`, which Learn documents as encrypted ([DSC extension template](https://learn.microsoft.com/azure/virtual-machines/extensions/dsc-template)).

The join runs first (`JsonADDomainExtension` or `AADLoginForWindows`), then the agent, then the Azure Monitor Agent, so the extensions don't race on the same VM.

Learn notes the DSC extension retires on 31 March 2028.

## Access and roles

| Who | Role | Scope | Why |
|---|---|---|---|
| Users and groups you name | Desktop Virtualization User | Desktop application group | To see the desktop ([Learn](https://learn.microsoft.com/azure/virtual-desktop/add-session-hosts-host-pool)). |
| The same users and groups (Entra join only) | Virtual Machine User Login | Resource group | Required to sign in to Microsoft Entra joined session hosts outside a session host configuration ([Learn](https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts)). |
| Azure Virtual Desktop service principal | Desktop Virtualization Power On Contributor | Resource group | Start VM on Connect. Learn: the assignment can be at a scope that contains the session host VMs ([Learn](https://learn.microsoft.com/azure/virtual-desktop/start-virtual-machine-connect)). |
| Support group (optional) | Desktop Virtualization User Session Operator | Host pool | Disconnect, sign out and message user sessions. Restarting a VM needs a role with `Microsoft.Compute/virtualMachines/restart/action`. |
| The person running the script | Key Vault Secrets Officer | Key Vault | Read the stored local administrator passwords. |

## Power management

Start VM on Connect is on by default. For a personal scaling plan (deallocate after a disconnect or sign-out), set `$EnableAutoscale = $true`. Learn says autoscale needs **Desktop Virtualization Power On Off Contributor for the Azure Virtual Desktop service principal at subscription scope**, and that a lower scope *"prevents autoscale from working properly"* ([Learn](https://learn.microsoft.com/azure/virtual-desktop/autoscale-create-assign-scaling-plan)). This template doesn't assign subscription-scope roles: ask your platform team to add it once per subscription.

The default schedule: weekdays, ramp-up 07:00, peak 09:00, ramp-down 17:00, off-peak 19:00; deallocate 90 minutes after a disconnect (30 off-peak) and 15 minutes after a sign-out.

## If a host doesn't register

1. Check the VM's extensions: `Get-AzVM -ResourceGroupName <rg> -Name <vm> -Status | Select-Object -ExpandProperty Extensions`.
2. **Join failed** (`JoinDomain`): usually the join account's password, its OU rights, or DNS to the domain controllers. Learn lists the OU permissions the join account needs ([Learn](https://learn.microsoft.com/azure/virtual-desktop/deploy-azure-virtual-desktop#prerequisites)).
3. **Entra join or Intune enrolment failed** (`AADLoginForWindows`): check `dsregcmd /status` on the VM, and Intune automatic enrolment (MDM user scope).
4. **Agent didn't register** (`Microsoft.PowerShell.DSC`): the DSC log is in `C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\`. The usual cause is outbound access to the [required FQDNs](https://learn.microsoft.com/azure/virtual-desktop/required-fqdn-endpoint), including TLS inspection.
5. To rebuild a host, delete the VM (its NIC and OS disk are set to delete with it), then run the script again. Existing healthy hosts are left alone.

## Microsoft Learn references

- [Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches)
- [Add session hosts to a host pool](https://learn.microsoft.com/azure/virtual-desktop/add-session-hosts-host-pool)
- [Microsoft Entra joined session hosts](https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts)
- [Configure single sign-on](https://learn.microsoft.com/azure/virtual-desktop/configure-single-sign-on)
- [Start VM on Connect](https://learn.microsoft.com/azure/virtual-desktop/start-virtual-machine-connect)
- [Create and assign an autoscale scaling plan](https://learn.microsoft.com/azure/virtual-desktop/autoscale-create-assign-scaling-plan)
- [Required FQDNs and endpoints](https://learn.microsoft.com/azure/virtual-desktop/required-fqdn-endpoint)
- [Desired State Configuration extension with ARM templates](https://learn.microsoft.com/azure/virtual-machines/extensions/dsc-template)
- [Azure Virtual Desktop Insights glossary](https://learn.microsoft.com/azure/virtual-desktop/insights-glossary) (the counters and event logs in the data collection rule)
- [Trusted launch for Azure VMs](https://learn.microsoft.com/azure/virtual-machines/trusted-launch)
- [Azure built-in roles for Compute](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/compute)
