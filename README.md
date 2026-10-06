# Azure Virtual Desktop North Star

[![Publish site](https://github.com/marckean/AVD-Reference_Architecture/actions/workflows/publish.yml/badge.svg)](https://github.com/marckean/AVD-Reference_Architecture/actions/workflows/publish.yml)
[![Validate toolkit](https://github.com/marckean/AVD-Reference_Architecture/actions/workflows/validate.yml/badge.svg)](https://github.com/marckean/AVD-Reference_Architecture/actions/workflows/validate.yml)

### 👉 Read the reference architecture: **[marckean.github.io/AVD-Reference_Architecture](https://marckean.github.io/AVD-Reference_Architecture/)**

A one-stop shop for modern pooled Azure Virtual Desktop. It has two halves:

- **The reference architecture** (the website): what good looks like, how the pieces fit together, the decisions you can't change later, and how to get there from where you are today.
- **The accelerators** (this repository): a discovery questionnaire, a Deploy to Azure wizard, App Attach and Intune toolkits, and instructions and skills so GitHub Copilot can help.

Every recommendation links back to Microsoft Learn.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmarckean%2FAVD-Reference_Architecture%2Fmain%2Fdeploy%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fmarckean%2FAVD-Reference_Architecture%2Fmain%2Fdeploy%2FcreateUiDefinition.json)

## What's here

| Step | Accelerator | Where |
| --- | --- | --- |
| **Learn** | The reference architecture: the North Star, reference architecture patterns, a master dependency map, sizing estimates, twelve areas in depth, a dependency checklist, stepping stones and a worked example. Every area runs from Level 100 (in plain terms) to Level 400 (under the hood) | [The website](https://marckean.github.io/AVD-Reference_Architecture/) |
| **Go deeper** | Identity demystified: Active Directory and Microsoft Entra ID, Kerberos tickets and the Primary Refresh Token, the device join models, Kerberos, NTLM and Negotiate, and how legacy and modern applications authenticate | [Identity demystified](https://marckean.github.io/AVD-Reference_Architecture/demystified/) |
| **Discover** | An interactive discovery questionnaire you fill in with the customer. It recommends patterns, flags fixed-at-creation decisions, estimates sizing, and writes a parameters file for the pilot. Answers never leave the browser | [Discovery questionnaire](https://marckean.github.io/AVD-Reference_Architecture/accelerators/discovery-questionnaire/) |
| **Deploy** | A Deploy to Azure template with a guided portal wizard that explains each component: an automated host pool, dynamic autoscaling, ephemeral OS disks, Microsoft Entra join, Azure Files and Key Vault | [deploy/](deploy/) |
| **Configure** | Intune settings catalog policy examples for multi-session session hosts, and a script that resolves every setting against your tenant before it creates anything | [tools/intune/](tools/intune/) |
| **Bring applications** | The App Attach toolkit: App-V and golden image inventory, triage rules, MSIX conversion templates, CimFS images, onboarding and share checks | [tools/app-attach/](tools/app-attach/) |
| **Work with AI** | Repository instructions, five agent skills and the Microsoft Learn MCP Server, so GitHub Copilot knows the architecture, the tools and the rules | [.github/](.github/), [.vscode/](.vscode/) |

## Quick start

1. **Read the North Star** on the [website](https://marckean.github.io/AVD-Reference_Architecture/), starting with [What good looks like](https://marckean.github.io/AVD-Reference_Architecture/overview/what-good-looks-like/) and the [reference architectures](https://marckean.github.io/AVD-Reference_Architecture/overview/reference-architectures/).
2. **Run discovery** with the [questionnaire](https://marckean.github.io/AVD-Reference_Architecture/accelerators/discovery-questionnaire/), and export the report and the parameters file.
3. **Deploy a pilot** with the button above, or with your parameters file:

    ```bash
    az deployment group create \
      --resource-group <resource-group> \
      --template-uri https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/azuredeploy.json \
      --parameters @azuredeploy.parameters.json
    ```

4. **Configure the session hosts** with the Intune policy examples:

    ```powershell
    ./tools/intune/Deploy-IntunePolicy.ps1 -OfflineValidationOnly
    ./tools/intune/Deploy-IntunePolicy.ps1 -WhatIf
    ```

5. **Bring the applications across** with the [App Attach fast track](https://marckean.github.io/AVD-Reference_Architecture/accelerators/app-attach-fast-track/):

    ```powershell
    ./tools/app-attach/Get-AppVPackageInventory.ps1 -Path \\contoso.file.core.windows.net\packages -Recurse -CsvPath ./appv-inventory.csv
    ./tools/app-attach/Get-ImageApplicationInventory.ps1 -Mode Online -CsvPath ./image-inventory.csv
    ```

Every script that changes something supports `-WhatIf`. Run it that way first, against a test group or a non-production environment.

## Repository map

```text
docs/                    The website (Material for MkDocs), published to GitHub Pages
deploy/                  Deploy to Azure: main.bicep, modules/, azuredeploy.json, createUiDefinition.json
tools/app-attach/        App Attach toolkit, with Pester tests
tools/intune/            Intune policy examples, deployment script and Pester tests
.github/
  copilot-instructions.md  Repository-wide instructions for GitHub Copilot
  skills/                  Agent skills: triage, onboarding, Intune policy, design review, discovery to deployment
  workflows/               Publish the site; validate the toolkit
.vscode/                 Microsoft Learn MCP Server and recommended extensions
scripts/                 House style check, template and wizard check, diagram generator and tests
```

## The North Star in one line

Pooled host pools of Windows 11 Enterprise multi-session, run by a session host configuration with session host update and dynamic autoscaling, on ephemeral OS disks. Session hosts are Microsoft Entra joined and Intune managed, images come from Azure Image Builder and Azure Compute Gallery, applications arrive through App Attach, and FSLogix profiles live on Azure Files with Microsoft Entra Kerberos.

## Working with GitHub Copilot

Open the repository in VS Code with GitHub Copilot. The [repository instructions](.github/copilot-instructions.md) tell Copilot the North Star, the grounding rules and the safety rules. The [skills](.github/skills/) teach it the workflows, and [.vscode/mcp.json](.vscode/mcp.json) adds the Microsoft Learn MCP Server so its answers come from current Microsoft documentation. Type `/` in Copilot Chat to see the skills. See [Working with AI](https://marckean.github.io/AVD-Reference_Architecture/accelerators/working-with-ai/) for more.

## Contributing

The website builds with [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/). To preview it locally:

```bash
pip install -r requirements.txt
mkdocs serve
```

Two GitHub Actions workflows run on every push:

- **Publish site** checks the house style, builds the site in strict mode and deploys it to GitHub Pages.
- **Validate toolkit** runs:
  - PSScriptAnalyzer and Pester on the PowerShell tools;
  - checks that every JSON file parses, and that the Bicep builds and lints;
  - checks that the portal wizard and the template agree;
  - rebuilds the diagrams, checks them with the layout lint, and runs the lint's own tests;
  - runs the discovery questionnaire tests.

Rebuild generated files after you change their source:

```bash
az bicep build --file deploy/main.bicep --outfile deploy/azuredeploy.json
python scripts/diagrams/build_all.py
```

House rules:

- Ground every Microsoft or Azure technical claim in Microsoft Learn, and link it.
- Mark every recommended feature as generally available or preview.
- Quote setting, role, property and parameter names exactly.
- Keep it generic: use Contoso in examples, and never put secrets or real organisation details in a file.
- Use plain hyphens only. The build fails on em or en dashes (`scripts/check_style.py`).

## Disclaimer

This is a community reference architecture and toolkit. It isn't official Microsoft guidance or a Microsoft product. Always confirm against the linked Microsoft Learn articles, and test in a non-production environment before you build.
