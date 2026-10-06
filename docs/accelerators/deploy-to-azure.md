---
title: Deploy to Azure
description: Stand up a pilot North Star environment from zero with one button - a guided Azure portal wizard that explains each component as you go, deploying a host pool with a session host configuration, dynamic autoscaling, ephemeral OS disks, Microsoft Entra join, Azure Files and Key Vault.
---

# Deploy to Azure

!!! abstract "At a glance"
    - One button opens the Azure portal with a guided wizard. Each step explains what the component is and why the North Star uses it, then collects the values it needs.
    - It deploys a pilot-sized North Star into one resource group: a pooled host pool with a session host configuration, Microsoft Entra joined session hosts on ephemeral OS disks, dynamic autoscaling, Azure Files for profiles and App Attach, Key Vault, networking and monitoring.
    - The deployment creates the first two session hosts itself, then dynamic autoscaling creates and deletes hosts to follow demand. It assigns the autoscale roles at subscription scope by default, so you need **Owner** or **User Access Administrator** on the subscription.
    - Some things can't be done by a template, such as tenant consent and file permissions. The wizard's last step and the template outputs list them.
    - It's a pilot, not a production landing zone. Use it to learn, test personas and prove the platform.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmarckean%2FAVD-Reference_Architecture%2Fmain%2Fdeploy%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fmarckean%2FAVD-Reference_Architecture%2Fmain%2Fdeploy%2FcreateUiDefinition.json)

The button opens the template from this repository with its custom portal wizard. Microsoft documents this pattern, a portal URL with the URL-encoded template location and an optional `createUIDefinitionUri`, in [Use a deployment button to deploy remote templates](https://learn.microsoft.com/azure/azure-resource-manager/templates/deploy-to-azure-button). The source is in [deploy/](https://github.com/marckean/AVD-Reference_Architecture/tree/main/deploy).

## Before you start

| You need | Why |
| --- | --- |
| A resource group, or permission to create one | Everything deploys into one resource group, so it's easy to remove |
| **Owner**, or **Contributor** plus **User Access Administrator**, on the subscription | The template creates role assignments, some of them at subscription scope for autoscale |
| A Microsoft Entra security group of pilot users | The template gives this group access to the desktop and the profile share |
| vCPU quota for the session host size you choose, in the region | The deployment and autoscale can't create hosts without quota ([Quotas](https://learn.microsoft.com/azure/quotas/view-quotas)) |
| The exact Marketplace image version | The session host configuration needs an exact version, not `latest`. The [deploy README](https://github.com/marckean/AVD-Reference_Architecture/blob/main/deploy/README.md#pin-the-image-version) has a one-line lookup |
| Intune licences and automatic MDM enrolment configured in the tenant | New session hosts are enrolled in Intune as they're created, and provisioning fails if enrolment fails ([Set up automatic enrollment](https://learn.microsoft.com/intune/device-enrollment/windows/quickstart-automatic-mdm#set-up-automatic-enrollment)) |
| Optionally, the object IDs of the **Azure Virtual Desktop** and **Azure Virtual Desktop ARM Provider** service principals | Needed for App Attach on Microsoft Entra joined session hosts ([Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup)). The wizard explains how to find them |

## The wizard, step by step

| Step | What it explains | What it asks for |
| --- | --- | --- |
| **Basics** | What the pilot is and what it isn't | Subscription, resource group, region and a name prefix |
| **Identity and access** | Microsoft Entra join, single sign-on, the local admin account in Key Vault, and the autoscale role model | The pilot users group, the local admin credentials, and the autoscale role options |
| **Networking** | Reverse connect, why no inbound ports are opened, and why outbound uses a NAT gateway | A new virtual network and subnet, or an existing subnet |
| **Session hosts** | Session host configuration, ephemeral OS disks and Trusted launch, and why only some sizes are offered | VM size, image and exact image version, Intune enrolment, host name prefix, sessions per host, availability zones and deployment scope |
| **Profiles and applications** | FSLogix on Azure Files with Microsoft Entra Kerberos, and App Attach | A private endpoint for Azure Files, and the App Attach service principal object IDs |
| **Scaling and monitoring** | Dynamic autoscaling and the weekday schedule, and diagnostics to Log Analytics | Time zone, and the minimum and maximum host pool sizes |
| **Next steps** | What the template can't do for you | Nothing; it's a checklist to read before you create |

## What gets deployed

| Component | What you get | Learn |
| --- | --- | --- |
| Host pool | Pooled, with the session host configuration management approach (`managementType` **Automated**), a user-assigned managed identity, and the RDP property for Microsoft Entra single sign-on | [Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches) |
| Session host configuration | Windows 11 Enterprise multi-session image, ephemeral OS disk on the temp disk, Trusted launch, Microsoft Entra join with Intune enrolment, and admin credentials read from Key Vault | [Session host configuration template reference](https://learn.microsoft.com/azure/templates/microsoft.desktopvirtualization/hostpools/sessionhostconfigurations) |
| Session host management policy | How hosts are created and updated, using the portal's documented defaults, and the first two session hosts | [Session host management policy](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches#session-host-management-policy) |
| Scaling plan | Dynamic autoscaling (`CreateDeletePowerManage`) with a weekday schedule | [Autoscale scenarios](https://learn.microsoft.com/azure/virtual-desktop/autoscale-scenarios) |
| Application group and workspace | A desktop application group, published through a workspace | [Terminology](https://learn.microsoft.com/azure/virtual-desktop/terminology) |
| Network | Virtual network and subnet, an NSG with no inbound allow rules, and a NAT gateway for outbound | [Default outbound access](https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access) |
| Storage | Premium Azure Files with Microsoft Entra Kerberos, a `profiles` share and an `appattach` share, and an optional private endpoint | [Microsoft Entra Kerberos for Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable) |
| Key Vault | Azure RBAC Key Vault holding the session host local admin credentials | [Deploy Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/deploy-azure-virtual-desktop) |
| Monitoring | Log Analytics workspace, plus diagnostic settings for the host pool, application group, workspace and scaling plan | [Diagnostics with Log Analytics](https://learn.microsoft.com/azure/virtual-desktop/diagnostics-log-analytics) |
| Role assignments | Access for the pilot users, the host pool identity's roles, and the autoscale roles described below | [Built-in RBAC roles for Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/rbac) |

### Why only some VM sizes are offered

Ephemeral OS disks live on the VM's local storage. Learn says the Windows 11 Enterprise multi-session image is 127 GiB, so for temp disk placement *"the temp disk size must be equal to or larger than 127 GiB"* ([Ephemeral OS disks on Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/deploy/session-hosts/ephemeral-os-disks)). Many sizes, such as the Dsv5 series, have no temp disk at all. So the wizard offers only sizes whose temp disk is big enough: the Dadsv5, Ddsv5 and Eadsv5 sizes listed in the [deploy README](https://github.com/marckean/AVD-Reference_Architecture/blob/main/deploy/README.md). Learn's ephemeral OS disk article also notes that ephemeral OS disks aren't supported with premium SSD (a note carried over from the preview). In live testing, the service rejected any managed disk type alongside the ephemeral settings with `MultipleDiskTypesSpecified`, *"Only one type of OS disk may be specified at one time"*, so the template sends the ephemeral disk settings only.

### Why the autoscale roles matter

In this deployment, the session host management policy creates the first hosts, and dynamic autoscaling then creates and deletes hosts to follow demand. Learn says dynamic autoscaling needs **Desktop Virtualization Power On Off Contributor** and **Desktop Virtualization Virtual Machine Contributor** *"with your Azure subscription as the assignable scope. If you assign this role at any level lower than your subscription ... it prevents autoscale from working properly"* ([Create and assign a scaling plan](https://learn.microsoft.com/azure/virtual-desktop/autoscale-create-assign-scaling-plan)). The template:

- always gives the host pool's managed identity **Desktop Virtualization Virtual Machine Contributor** on the resource group, which Learn lists as a prerequisite for session host configuration ([Deploy Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/deploy-azure-virtual-desktop#prerequisites));
- by default, gives the managed identity both autoscale roles at subscription scope;
- optionally, gives the **Azure Virtual Desktop** service principal the same roles. This is off by default because many tenants that already use autoscale have these assignments, and Azure Resource Manager fails a deployment that tries to create the same role assignment again under a different name (`RoleAssignmentExists`).

If session hosts fail to appear or show **ProvisioningFailed**, read the session host management policy's provisioning status, which reports the error for each host. The [deploy README](https://github.com/marckean/AVD-Reference_Architecture/blob/main/deploy/README.md#intune-enrolment) has the command. Then check the service principal's roles; the README has the read-only check and the commands to assign anything missing.

### A note on API versions

Session host configuration is generally available, but every API version Microsoft publishes for the `hostPools/sessionHostConfigurations` resource is a preview API version ([template reference](https://learn.microsoft.com/azure/templates/microsoft.desktopvirtualization/hostpools/sessionhostconfigurations)). So the template uses the newest one, `2026-04-01-preview`. Check the template reference for a newer version before you take the template into production.

## What live testing found

The template was deployed end to end in a test subscription in Australia East in October 2026. Each problem below was hit for real, and the template now avoids it.

| What happened | Why | What the template does |
| --- | --- | --- |
| `MarketplaceImageNotFound` with `exactVersion` set to `latest` | The session host configuration needs an exact image version | Requires an exact version. The README and the discovery questionnaire look up the newest one |
| `MultipleDiskTypesSpecified`, *"Only one type of OS disk may be specified at one time"* | A managed disk type alongside the ephemeral disk settings is rejected | Sends the ephemeral disk settings only |
| No ephemeral OS disk support on the default size | Sizes such as Standard_D8s_v5 have no temp disk | Offers only sizes with a temp disk of at least 127 GiB |
| `RegionalScopeNotAvailable` | Regional host pools are available only in supported regions | Defaults to the Geographical deployment scope |
| *"Metric export is not enabled"* on the diagnostic settings | Azure Virtual Desktop resources export logs, not metrics | Sends all logs and no metrics |
| `RoleAssignmentExists` | The tenant already had the autoscale roles assigned to the Azure Virtual Desktop service principal | Assigns the autoscale roles to the new managed identity, and leaves the service principal option off by default |
| *"Session Host Management does not exist for the hostpool"* when creating the scaling plan | The portal creates the session host management policy automatically, but an ARM deployment must declare it | Declares the policy with the portal's documented defaults |
| `MdmJoinFailed` about 30 minutes after the hosts were created | Intune enrolment wasn't working in the test tenant, and provisioning treats a failed enrolment as a failed host | Checks Intune readiness in [Before you start](#before-you-start), and adds a lab-only option to skip enrolment |

With Intune enrolment turned off, the same deployment completed in about ten minutes, with two session hosts **Available** and the scaling plan in place. Raising the scaling plan's minimum host pool size then made autoscale start creating a third host within seconds. The host pool's managed identity created every host, while the Azure Virtual Desktop service principal held only **Desktop Virtualization Power On Off Contributor**. That's why the template assigns the autoscale roles to the managed identity and leaves the service principal option off by default.

Some things you'll see that are normal:

- **No Microsoft Entra join extension on the VMs.** With a session host configuration, *"the domain join extension isn't used ... Instead, the Azure Virtual Desktop agent completes the domain join process"* ([Troubleshoot session host configuration](https://learn.microsoft.com/troubleshoot/azure/virtual-desktop/troubleshoot-session-host-configuration-update#errors-when-adding-session-hosts-to-a-host-pool)). Run `dsregcmd /status` on a host to confirm the join.
- **No managed disk resources for the session hosts.** The OS disk is ephemeral, so it lives on the VM's local storage.
- **A relayed RDP Shortpath path.** Behind the NAT gateway, the session host's TURN relay health check reports a symmetric NAT and succeeds. Clients on the internet get UDP through TURN ([RDP Shortpath](https://learn.microsoft.com/azure/virtual-desktop/rdp-shortpath)).
- **A long deployment.** The deployment waits while the first hosts are created, joined and registered.

## After the deployment

The template outputs these steps, and the wizard shows them before you create:

1. Enable Microsoft Entra authentication for RDP, and review Conditional Access for **Azure Virtual Desktop** and **Windows Cloud Login** ([Configure single sign-on](https://learn.microsoft.com/azure/virtual-desktop/configure-single-sign-on)).
2. Grant admin consent for the storage account's Microsoft Entra Kerberos application ([Enable Microsoft Entra Kerberos for Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable)).
3. Set directory and file permissions on the `profiles` share, so each user can only reach their own profile.
4. Deploy the Intune policies for Kerberos ticket retrieval, FSLogix and the rest, using the [policy examples](../intune/policy-examples.md).
5. Add signed App Attach packages to the `appattach` share and onboard them, using the [App Attach fast track](app-attach-fast-track.md).
6. Sign in as a pilot user and check single sign-on, profile attach and an App Attach application.

## Deploy with your discovery answers

The [Discovery questionnaire](discovery-questionnaire.md) produces an `azuredeploy.parameters.json` file for this template. To deploy with it instead of the wizard:

=== "Azure CLI"

    ```bash
    az deployment group create \
      --resource-group <resource-group> \
      --template-uri https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/azuredeploy.json \
      --parameters @azuredeploy.parameters.json
    ```

=== "Azure PowerShell"

    ```powershell
    New-AzResourceGroupDeployment `
      -ResourceGroupName <resource-group> `
      -TemplateUri https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/azuredeploy.json `
      -TemplateParameterFile ./azuredeploy.parameters.json
    ```

Both prompt for the local admin password, which is never written to the parameters file ([Deploy with Azure CLI](https://learn.microsoft.com/azure/azure-resource-manager/templates/deploy-cli), [Deploy with Azure PowerShell](https://learn.microsoft.com/azure/azure-resource-manager/templates/deploy-powershell)). If you left the image version blank in the questionnaire, the commands it generates look up the newest version first and pass it in. Run `az deployment group what-if` with the same arguments first to see what would change.

## Clean up

Delete the resource group to remove the pilot. The subscription-scope role assignments sit outside the resource group, so remove those separately.

---

Part of [Accelerators](index.md).
