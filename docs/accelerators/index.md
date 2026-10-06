---
title: Accelerators
description: Tools in the repository that take an organisation from zero to a working North Star faster - a discovery questionnaire, a Deploy to Azure wizard, App Attach and Intune toolkits, and AI assistance.
---

# Accelerators

!!! abstract "At a glance"
    - The rest of this site says what good looks like. This section gives you the tools to get there faster.
    - Discover with the questionnaire, deploy a pilot with one button, configure hosts with the Intune examples, bring applications across with the App Attach toolkit, and let GitHub Copilot do the repetitive work.
    - The tools live in the [GitHub repository](https://github.com/marckean/AVD-Reference_Architecture), not on this website. Clone or download it to use them.
    - Everything is generic and grounded in Microsoft Learn. Read each tool's notes on what has and hasn't been tested before you rely on it.

## From zero to a working pilot

<div class="grid cards" markdown>

-   :material-clipboard-list-outline:{ .lg .middle } __[1. Discover](discovery-questionnaire.md)__

    ---

    Fill in the discovery questionnaire with the customer. It recommends reference architecture patterns, flags the decisions you can't change later, estimates sizing, and writes a parameters file for the pilot.

-   :material-rocket-launch-outline:{ .lg .middle } __[2. Deploy a pilot](deploy-to-azure.md)__

    ---

    One button opens a guided Azure portal wizard that explains each component, then deploys an automated host pool, dynamic autoscaling, ephemeral OS disks, Azure Files and Key Vault.

-   :material-tune-vertical:{ .lg .middle } __[3. Configure the hosts](../intune/policy-examples.md)__

    ---

    Intune policy examples for Microsoft Entra Kerberos, FSLogix, Defender exclusions, clipboard direction and Windows LAPS, deployed by a script that checks every setting against your tenant first.

-   :material-package-variant-closed:{ .lg .middle } __[4. Bring the applications](app-attach-fast-track.md)__

    ---

    The App Attach fast track: inventory App-V packages or a golden image, triage them, onboard App-V packages as they are, then convert the rest from source.

-   :material-robot-outline:{ .lg .middle } __[5. Work with AI](working-with-ai.md)__

    ---

    Repository instructions, agent skills and the Microsoft Learn MCP Server, so GitHub Copilot knows the architecture, the tools and the rules.

-   :material-map-marker-path:{ .lg .middle } __[6. Learn from an example](../getting-there/worked-example.md)__

    ---

    A worked example of a large organisation adopting the North Star in phases, with the stepping stones it needed along the way.

</div>

## Where the tools live

| Folder | What's in it |
| --- | --- |
| [deploy/](https://github.com/marckean/AVD-Reference_Architecture/tree/main/deploy) | The Deploy to Azure template, in Bicep and compiled ARM JSON, and the portal wizard |
| [tools/app-attach/](https://github.com/marckean/AVD-Reference_Architecture/tree/main/tools/app-attach) | App-V and golden image inventory, triage rules, MSIX conversion templates, image creation, App Attach onboarding and share checks |
| [tools/intune/](https://github.com/marckean/AVD-Reference_Architecture/tree/main/tools/intune) | Intune policy examples and the deployment script |
| [.github/skills/](https://github.com/marckean/AVD-Reference_Architecture/tree/main/.github/skills) | Agent skills for GitHub Copilot |
| [.vscode/mcp.json](https://github.com/marckean/AVD-Reference_Architecture/blob/main/.vscode/mcp.json) | The Microsoft Learn MCP Server for grounded answers |

The discovery questionnaire runs right here on the site, in your browser.

## How they're checked

| Accelerator | Checks |
| --- | --- |
| Deploy to Azure | Bicep build and lint, the ARM template test toolkit, schema validation of the portal wizard, a check that every wizard output matches a template parameter, Azure Resource Manager validate and what-if, and live test deployments |
| PowerShell tools | PSScriptAnalyzer and Pester tests run in GitHub Actions on every change. The tests use synthetic data, and scripts that change Azure or Intune support `-WhatIf` |
| Discovery questionnaire | Logic tests that check every generated parameter against the template's allowed values |
| Diagrams | A layout lint that fails the build on overlapping or truncated elements |

!!! warning "Use them as a starting point"
    These are community accelerators, not Microsoft products. The scripts that change Azure resources or Intune policies haven't been run against every kind of tenant. Run them with `-WhatIf` first, test in a non-production environment, and review everything with the people who own it.
