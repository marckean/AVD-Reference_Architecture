# Deploy the AVD North Star pilot

This folder contains a portal-driven deployment for a pilot-sized Azure Virtual Desktop North Star environment. It uses a custom Azure portal wizard in [createUiDefinition.json](createUiDefinition.json) and an ARM template compiled from [main.bicep](main.bicep).

The deployment is generic. Examples use Contoso only.

## Deploy to Azure

Use this button from the repository README or the published site:

```markdown
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmarckean%2FAVD-Reference_Architecture%2Fmain%2Fdeploy%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fmarckean%2FAVD-Reference_Architecture%2Fmain%2Fdeploy%2FcreateUiDefinition.json)
```

Microsoft documents the Deploy to Azure button as a portal URL that starts with `https://portal.azure.com/#create/Microsoft.Template/uri/` and appends the URL-encoded raw template URL. This deployment also appends a URL-encoded `createUIDefinitionUri` so the portal uses the custom wizard. See [Use a deployment button to deploy remote templates](https://learn.microsoft.com/azure/azure-resource-manager/templates/deploy-to-azure-button).

## What gets deployed

| Component | What the template deploys | Why it is in the North Star |
| --- | --- | --- |
| Azure Virtual Desktop host pool | A pooled host pool with `managementType` set to `Automated`, a user-assigned managed identity, Microsoft Entra single sign-on RDP property and a session host configuration. | Session host configuration defines disposable session hosts and is the source of truth for automated host pools. See [Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches). |
| Session host configuration | Windows 11 Enterprise multi-session marketplace image choice, VM size, ephemeral OS disk, Trusted launch, Microsoft Entra join, Intune MDM provider GUID, subnet, VM prefix, zones and Key Vault credential references. | Microsoft Learn lists these as session host configuration properties. See [hostPools/sessionHostConfigurations](https://learn.microsoft.com/azure/templates/microsoft.desktopvirtualization/hostpools/sessionhostconfigurations). |
| Session host management policy | A `Microsoft.DesktopVirtualization/hostPools/sessionHostManagements` child resource named `default`, using the documented portal defaults for update behaviour and a provisioning `instanceCount` based on the ramp-up minimum host pool size. | The session host management policy specifies how session hosts are created and updated, and the scaling plan requires it before host creation works. See [hostPools/sessionHostManagements](https://learn.microsoft.com/azure/templates/microsoft.desktopvirtualization/hostpools/sessionhostmanagements) and [Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches#session-host-management-policy). |
| Application group and workspace | A desktop application group linked to an Azure Virtual Desktop workspace. | Users access desktops through application groups and workspaces. See [Azure Virtual Desktop terminology](https://learn.microsoft.com/azure/virtual-desktop/terminology). |
| Scaling plan | Dynamic autoscaling with a weekday schedule and `CreateDeletePowerManage`. | Dynamic autoscaling can create and delete hosts for pooled host pools with session host configuration. See [Autoscale scaling plans](https://learn.microsoft.com/azure/virtual-desktop/autoscale-scenarios). |
| Identity and RBAC | Desktop Virtualization User on the application group, Key Vault Secrets User for the host pool identity, Desktop Virtualization Virtual Machine Contributor for the host pool managed identity on the resource group, and configurable subscription-scope autoscale roles. No Virtual Machine User Login assignment, because Learn says it isn't required for host pools using a session host configuration. | Microsoft documents these role requirements for users, Microsoft Entra joined VMs, session host configuration and autoscale. See [Microsoft Entra joined session hosts](https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts#assign-user-access-to-host-pools), [Deploy Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/deploy-azure-virtual-desktop#prerequisites) and [Create and assign an autoscale scaling plan](https://learn.microsoft.com/azure/virtual-desktop/autoscale-create-assign-scaling-plan). |
| Networking | Optional new VNet, session host subnet, NSG with no inbound allow rules, NAT Gateway and public IP. Existing subnet is also supported. | Azure Virtual Desktop uses reverse connect, and Microsoft recommends explicit outbound access rather than relying on default outbound access. See [Default outbound access in Azure](https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access) and [What is Azure NAT Gateway?](https://learn.microsoft.com/azure/nat-gateway/nat-overview). |
| Storage | Premium Azure Files storage account with `directoryServiceOptions` set to `AADKERB`, separate `profiles` and `appattach` shares, share-level RBAC for the pilot users group and optional private endpoint. | FSLogix uses Azure Files with Microsoft Entra Kerberos, and App Attach packages need SMB storage in the same region as the session hosts. See [Enable Microsoft Entra Kerberos for Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable) and [Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup). |
| Key Vault | Azure RBAC-enabled Key Vault that stores the session host local admin username and password as secrets. | The session host configuration template reference supports `usernameKeyVaultSecretUri` and `passwordKeyVaultSecretUri` for VM admin credentials. See [hostPools/sessionHostConfigurations](https://learn.microsoft.com/azure/templates/microsoft.desktopvirtualization/hostpools/sessionhostconfigurations). |
| Monitoring | Log Analytics workspace and diagnostic settings for the host pool, application group, workspace and scaling plan. | Azure Virtual Desktop diagnostics and Autoscale diagnostics feed Log Analytics and Azure Virtual Desktop Insights. See [Diagnostics with Log Analytics](https://learn.microsoft.com/azure/virtual-desktop/diagnostics-log-analytics) and [Autoscale diagnostics](https://learn.microsoft.com/azure/virtual-desktop/autoscale-diagnostics). |

## Cost drivers

No prices are hard-coded here because costs depend on region, commitment, VM family, storage capacity, profile growth, data retention and network egress. The main cost drivers are:

- Session host compute created by dynamic autoscaling.
- NAT Gateway hourly and data processing charges.
- Premium Azure Files provisioned capacity and operations.
- Log Analytics ingestion and retention.
- Key Vault operations and private endpoint resources if enabled.

Use the official pricing pages before deploying outside a lab:

- [Azure Virtual Desktop pricing](https://azure.microsoft.com/pricing/details/virtual-desktop/)
- [Virtual Machines pricing](https://azure.microsoft.com/pricing/details/virtual-machines/windows/)
- [Azure Files pricing](https://azure.microsoft.com/pricing/details/storage/files/)
- [NAT Gateway pricing](https://azure.microsoft.com/pricing/details/azure-nat-gateway/)
- [Azure Monitor pricing](https://azure.microsoft.com/pricing/details/monitor/)
- [Key Vault pricing](https://azure.microsoft.com/pricing/details/key-vault/)

## Why the wizard offers only these VM sizes

The host pool uses ephemeral OS disks with `diffDiskSettings.placement` set to `TempDisk`. Microsoft Learn says the Windows 11 Enterprise multi-session marketplace image is 127 GiB and the temp disk size must be equal to or larger than that image size for temp disk placement. Learn also says Trusted launch reserves 1 GiB from the local placement used for VM guest state. See [Ephemeral OS disks on Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/deploy/session-hosts/ephemeral-os-disks) and [Ephemeral OS disks for Azure VMs](https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks).

For that reason, the wizard uses a curated list of v5 sizes with documented temp disks of at least 150 GiB:

| Size | Temp disk from Microsoft Learn | Source |
| --- | ---: | --- |
| `Standard_D4ads_v5` | 150 GiB | [Dadsv5 sizes](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dadsv5-series) |
| `Standard_D8ads_v5` | 300 GiB | [Dadsv5 sizes](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dadsv5-series) |
| `Standard_D16ads_v5` | 600 GiB | [Dadsv5 sizes](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dadsv5-series) |
| `Standard_D4ds_v5` | 150 GiB | [Ddsv5 sizes](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/ddsv5-series) |
| `Standard_D8ds_v5` | 300 GiB | [Ddsv5 sizes](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/ddsv5-series) |
| `Standard_D16ds_v5` | 600 GiB | [Ddsv5 sizes](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/ddsv5-series) |
| `Standard_E8ads_v5` | 300 GiB | [Eadsv5 sizes](https://learn.microsoft.com/azure/virtual-machines/sizes/memory-optimized/eadsv5-series) |

No-local-disk sizes such as `Standard_D8s_v5`, `Standard_D8as_v5` and `Standard_D8as_v6` are intentionally excluded. v6 local-disk sizes such as `Standard_D8ads_v6` and `Standard_D8ds_v6` use NVMe placement rather than temp disk placement. Learn documents NVMe disk placement for ephemeral OS disks in Azure VMs, but the current Azure Virtual Desktop session host configuration template reference used here lists only `CacheDisk` and `TempDisk` for `diffDiskSettings.placement`. The deployment therefore leaves v6 NVMe sizes out until the session host configuration template reference documents `NvmeDisk` for that property.

## Pin the image version

The session host configuration template reference requires `imageInfo.marketplaceInfo.exactVersion` as a string. Live testing showed that `latest` is not accepted for this property, so this deployment always supplies an exact marketplace image version.

The portal wizard asks for the exact version in a required text box. A dynamic version dropdown was not used because the published `CreateUIDefinition.MultiVm` schema used by the validation tooling rejects `Microsoft.Solutions.ArmApiControl` in this wizard, even though the control itself is documented. The Compute REST operation for image versions is documented at [Virtual Machine Images - List](https://learn.microsoft.com/rest/api/compute/virtual-machine-images/list), and the wizard control is documented at [Microsoft.Solutions.ArmApiControl](https://learn.microsoft.com/azure/azure-resource-manager/managed-applications/microsoft-solutions-armapicontrol).

Get the newest version first, then paste it into the wizard or parameter file.

Azure CLI:

```powershell
$location = 'australiaeast'
$offer = 'office-365'
$sku = 'win11-26h2-avd-m365'
az vm image list -l $location -p MicrosoftWindowsDesktop -f $offer -s $sku --all --query "[-1].version" -o tsv
```

Azure PowerShell:

```powershell
$location = 'australiaeast'
$offer = 'office-365'
$sku = 'win11-26h2-avd-m365'
Get-AzVMImage -Location $location -PublisherName MicrosoftWindowsDesktop -Offer $offer -Skus $sku | Select-Object -Last 1 -ExpandProperty Version
```

Microsoft documents `az vm image list` for marketplace image discovery and `Get-AzVMImage` for listing image versions in [Find and use Azure Marketplace VM images with Azure PowerShell](https://learn.microsoft.com/azure/virtual-machines/windows/cli-ps-findimage).

## Host pool deployment scope

The wizard defaults `hostPoolDeploymentScope` to `Geographical`, which is the standard host pool metadata behaviour. The host pool template reference lists the exact `deploymentScope` property values as `Geographical` and `Regional` for `Microsoft.DesktopVirtualization/hostPools`.

Regional host pools are generally available, but the regional host pool article says they are available only in supported regions. It also says the PowerShell `DeploymentScope` parameter defaults to `Geographical` if it is not set. Use `Regional` only after confirming that the selected Azure region supports regional host pools. See [Regional Host Pools](https://learn.microsoft.com/azure/virtual-desktop/regional-host-pools) and the [hostPools template reference](https://learn.microsoft.com/azure/templates/microsoft.desktopvirtualization/hostpools).

## Intune enrolment

`enrollSessionHostsInIntune` defaults to `true`, which is the North Star: every new session host is enrolled in Intune as it's created. With a session host configuration, the Azure Virtual Desktop agent does the domain join instead of a VM extension ([Troubleshoot session host configuration](https://learn.microsoft.com/troubleshoot/azure/virtual-desktop/troubleshoot-session-host-configuration-update#errors-when-adding-session-hosts-to-a-host-pool)), and session host provisioning then enrols the host in Intune.

Check the tenant before you deploy:

- Users and session hosts are licensed for Intune ([Windows Enterprise multi-session with Intune](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session#prerequisites)).
- Automatic MDM enrolment is configured in the Intune admin center ([Set up automatic enrollment](https://learn.microsoft.com/intune/device-enrollment/windows/quickstart-automatic-mdm#set-up-automatic-enrollment)).

In live testing in a tenant where enrolment wasn't working, both session hosts were created, joined to Microsoft Entra ID and registered with the host pool. Provisioning still failed after about 30 minutes with `MdmJoinFailed` (*"IntuneEnrollmentProvisioningService exceeded the Maximum retries"*). The deployment then failed at the session host management policy, so the scaling plan was never created. To see the error, read the provisioning status of the session host management policy:

```powershell
az rest --method get --url "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.DesktopVirtualization/hostPools/<host-pool>/sessionHostManagements/default/sessionHostProvisioningStatuses/default?api-version=2026-04-01-preview"
```

Set `enrollSessionHostsInIntune` to `false` only for a lab without Intune. The template then omits `azureActiveDirectoryInfo` from the session host configuration, so hosts are Microsoft Entra joined but not managed. The North Star depends on Intune for the Kerberos ticket retrieval and FSLogix settings, so a host pool built this way isn't the North Star.

## Permissions needed

The deploying user needs write access to the resources being deployed and access to `Microsoft.Resources/deployments/*`, which Microsoft documents for ARM template deployments in [Use a deployment button to deploy remote templates](https://learn.microsoft.com/azure/azure-resource-manager/templates/deploy-to-azure-button).

Additional permission notes:

1. The host pool managed identity is always assigned **Desktop Virtualization Virtual Machine Contributor** at resource group scope, because Microsoft says the host pool managed identity needs that role on the resource group or subscription used for session hosts in [Deploy Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/deploy-azure-virtual-desktop#prerequisites).
2. Dynamic autoscaling creates the session hosts in this deployment. Microsoft says **Desktop Virtualization Power On Off Contributor** and **Desktop Virtualization Virtual Machine Contributor** must be assigned at subscription scope for dynamic autoscaling, and that lower scopes prevent autoscale from working properly. The wizard assigns these roles to the new host pool managed identity by default. The deploying user needs `Microsoft.Authorization/roleAssignments/write` at subscription scope, which Microsoft says is part of **Owner** and **User Access Administrator** in [Create and assign an autoscale scaling plan](https://learn.microsoft.com/azure/virtual-desktop/autoscale-create-assign-scaling-plan).
3. Learn's dynamic autoscaling article also names the **Azure Virtual Desktop** service principal. Many tenants that already use autoscale already have these assignments. Creating a duplicate assignment for the same principal, role and scope under a different assignment name fails with `RoleAssignmentExists`, so the wizard does not assign those roles to the service principal by default. Microsoft lists the Azure Virtual Desktop application ID as `9cdead84-a844-4324-93f2-b2e6bb768d07`; find that Enterprise application in your tenant and copy its object ID. See [Assign Azure RBAC roles or Microsoft Entra roles to a service principal](https://learn.microsoft.com/azure/virtual-desktop/service-principal-assign-roles).
4. If session hosts aren't created after deployment, first read the session host management policy's provisioning status, which reports the error for each host (see [Intune enrolment](#intune-enrolment)). Then check that the host pool's managed identity has both autoscale roles at subscription scope. In live testing, the managed identity created every host, including an autoscale scale-out, while the Azure Virtual Desktop service principal held only **Desktop Virtualization Power On Off Contributor**. Assign only missing roles.
5. The wizard asks for the pilot users group object ID. The template assigns **Desktop Virtualization User** and Azure Files share access to that group. It doesn't assign **Virtual Machine User Login**, which isn't required for Microsoft Entra joined session hosts in a host pool with a session host configuration.
6. For App Attach on Microsoft Entra joined session hosts using Azure Files, Microsoft says **Azure Virtual Desktop** and **Azure Virtual Desktop ARM Provider** need **Reader and Data Access** on the storage account. Their object IDs vary per tenant, so the wizard takes them as optional parameters. See [Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup).

Read-only check for the Azure Virtual Desktop service principal:

```powershell
$subscriptionId = '<subscription-id>'
$scope = "/subscriptions/$subscriptionId"
$avdSpObjectId = az ad sp show --id 9cdead84-a844-4324-93f2-b2e6bb768d07 --query id -o tsv
az role assignment list --assignee-object-id $avdSpObjectId --scope $scope --query "[?roleDefinitionName=='Desktop Virtualization Power On Off Contributor' || roleDefinitionName=='Desktop Virtualization Virtual Machine Contributor'].{role:roleDefinitionName,scope:scope}" -o table
```

Assign missing service principal roles if needed:

```powershell
$subscriptionId = '<subscription-id>'
$scope = "/subscriptions/$subscriptionId"
$avdSpObjectId = az ad sp show --id 9cdead84-a844-4324-93f2-b2e6bb768d07 --query id -o tsv
az role assignment create --assignee-object-id $avdSpObjectId --assignee-principal-type ServicePrincipal --role "Desktop Virtualization Power On Off Contributor" --scope $scope
az role assignment create --assignee-object-id $avdSpObjectId --assignee-principal-type ServicePrincipal --role "Desktop Virtualization Virtual Machine Contributor" --scope $scope
```

## CLI deployment

Compile the Bicep first:

```powershell
az bicep build --file .\deploy\main.bicep --outfile .\deploy\azuredeploy.json
```

Deploy at resource group scope:

```powershell
az deployment group create `
  --resource-group <resource-group-name> `
  --template-file .\deploy\azuredeploy.json `
  --parameters .\deploy\azuredeploy.parameters.example.json
```

Do not use the example password in [azuredeploy.parameters.example.json](azuredeploy.parameters.example.json). Replace it at deployment time or pass secure parameters separately.

## PowerShell deployment

```powershell
New-AzResourceGroupDeployment `
  -ResourceGroupName <resource-group-name> `
  -TemplateFile .\deploy\azuredeploy.json `
  -TemplateParameterFile .\deploy\azuredeploy.parameters.example.json
```

## Post-deployment steps

The template outputs these same steps so they are visible in the Azure portal after deployment.

1. Enable Microsoft Entra authentication for RDP if it is not already enabled. Microsoft documents this as setting `isRemoteDesktopProtocolEnabled` on **Windows Cloud Login** in [Configure single sign-on](https://learn.microsoft.com/azure/virtual-desktop/configure-single-sign-on).
2. Review Conditional Access policies for both **Azure Virtual Desktop** and **Windows Cloud Login**. See [Enforce MFA for Azure Virtual Desktop using Conditional Access](https://learn.microsoft.com/azure/virtual-desktop/set-up-mfa).
3. Configure Intune Settings Catalog policy `Kerberos/CloudKerberosTicketRetrievalEnabled` = `1` for the session hosts. Microsoft says the OMA-URI method does not work on Azure Virtual Desktop multi-session devices in [Enable Microsoft Entra Kerberos for Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable).
4. Configure FSLogix profile settings, including `VHDLocations`, using Intune or policy. See [FSLogix configuration setting reference](https://learn.microsoft.com/fslogix/reference-configuration-settings).
5. Complete Microsoft Entra Kerberos admin consent and any tenant storage identity prerequisites that ARM cannot complete for you. See [Enable Microsoft Entra Kerberos authentication for Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable).
6. Set directory and file level permissions on the profiles share so each user can create and access only their own profile folder. Microsoft says share-level permissions are only the first layer in [Assign share-level permissions for Azure file shares](https://learn.microsoft.com/azure/storage/files/storage-files-identity-assign-share-level-permissions).
7. Upload signed App Attach packages to the `appattach` share and add applications after at least one session host is powered on. See [Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup).
8. Confirm the subscription-scope autoscale roles exist before waiting for hosts to appear. Dynamic autoscaling creates the hosts. The template assigns both roles to the host pool managed identity by default. If hosts are not created, run the read-only Azure CLI check above for the Azure Virtual Desktop service principal, then assign only missing roles.
9. Pin the marketplace image version. The portal wizard requires an exact version. Use the Azure CLI or Azure PowerShell one-liners above and pass the exact version to `marketplaceImageVersion`.

## Clean-up

For a lab deployment, delete the resource group after testing:

```powershell
Remove-AzResourceGroup -Name <resource-group-name>
```

If you deployed into an existing resource group or existing subnet, review resources before deletion. Subscription-scope role assignments created by the nested deployment are outside the resource group and may need to be removed separately.

## Known limitations

- The template does not grant tenant admin consent for Azure Files Microsoft Entra Kerberos.
- The template does not set NTFS permissions inside the Azure Files shares.
- The template does not create App Attach packages or application objects.
- The template declares the session host management policy with the portal's documented defaults: a batch size of 1, a 2-minute sign-out delay and **KeepAll** for failed hosts, with the scaling plan's time zone instead of UTC. Review them before production. Every API version of this resource, like the session host configuration, is a preview API version ([template reference](https://learn.microsoft.com/azure/templates/microsoft.desktopvirtualization/hostpools/sessionhostmanagements)).
- The Intune MDM provider GUID is set to the value used by the Azure Virtual Desktop first-party template examples. Microsoft Learn documents the `mdmProviderGuid` property but the deployment article does not state the GUID value.
