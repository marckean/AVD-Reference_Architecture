---
name: discovery-to-deployment
description: Turn the output of the site's Discovery questionnaire (avd-discovery-answers.json, azuredeploy.parameters.json or the Markdown report) into a design summary, a checked parameters file for the Deploy to Azure template in deploy/, the deployment commands, and the post-deployment steps. Use when someone has completed discovery and wants to deploy the North Star pilot, or wants their parameters checked against the template.
argument-hint: "[path to avd-discovery-answers.json or azuredeploy.parameters.json]"
---

# From discovery to a deployed pilot

The [Discovery questionnaire](../../../docs/accelerators/discovery-questionnaire.md) runs in the browser. It exports:

- `avd-discovery-answers.json` (the answers, with `version` and `answers` keys)
- `azuredeploy.parameters.json` (parameters for the pilot template)
- `avd-discovery-report.md` (a readable report)

The template is [deploy/azuredeploy.json](../../../deploy/azuredeploy.json), built from [deploy/main.bicep](../../../deploy/main.bicep) and explained in the [deploy README](../../../deploy/README.md).

## Steps

1. **Summarise the design.** List the reference architecture patterns the answers point to, the decisions fixed at host pool creation, and the open dependencies. Use the [north-star-review](../north-star-review/SKILL.md) skill if the person wants a fuller review.
2. **Check the parameters against the template.** Read the `parameters` section of `deploy/azuredeploy.json` and check that:
   - every parameter in the file exists in the template;
   - every value respects the template's `allowedValues` (for example, `sessionHostVmSize` only allows the sizes that support ephemeral OS disks on the temp disk, and the image offer and SKU must be a matching pair);
   - nothing secret is in the file, especially `localAdminPassword`, which must be supplied at deployment time.
3. **Give the deployment commands** for the published template, with the local parameters file, in both Azure CLI (`az deployment group create --template-uri ... --parameters @azuredeploy.parameters.json`) and Azure PowerShell (`New-AzResourceGroupDeployment -TemplateUri ... -TemplateParameterFile ...`). Point out that the portal button uses the guided wizard instead.
4. **List the post-deployment steps** from the deploy README: admin consent for Microsoft Entra Kerberos on the storage account, directory and file permissions on the profiles share, the Intune policies in `tools/intune`, and App Attach onboarding in `tools/app-attach`.
5. **Remind the person** that the subscription-scope role assignments matter: dynamic autoscaling creates the session hosts, and Learn requires its roles at subscription scope ([Create and assign a scaling plan](https://learn.microsoft.com/azure/virtual-desktop/autoscale-create-assign-scaling-plan)).

## Rules

- Never write a password or secret into a file, and don't echo one back.
- Don't run the deployment for the person unless they ask. Suggest a what-if first: `az deployment group what-if`.
- Verify Azure facts on Microsoft Learn rather than from memory.
