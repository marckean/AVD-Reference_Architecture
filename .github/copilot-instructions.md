# Copilot instructions for the AVD North Star repository

This repository is a community reference architecture for pooled Azure Virtual Desktop (AVD), plus the accelerators that help an organisation adopt it. It has five parts:

- `docs/` - the documentation site, built with Material for MkDocs and published to GitHub Pages at https://marckean.github.io/AVD-Reference_Architecture/
- `deploy/` - a Deploy to Azure template: Bicep compiled to `azuredeploy.json`, with a guided portal wizard in `createUiDefinition.json`
- `tools/app-attach/` - PowerShell accelerators for moving applications, including App-V packages, to App Attach
- `tools/intune/` - Intune policy examples for Microsoft Entra joined multi-session session hosts, and a script that deploys them
- `scripts/` - site build helpers: the house style check and the diagram generator

Agent skills for common tasks live in `.github/skills/`.

## The North Star

Treat [What good looks like](../docs/overview/what-good-looks-like.md) as the target state and the [dependency checklist](../docs/getting-there/dependencies.md) as the build order. In short:

- Pooled host pools that use a session host configuration, session host update and dynamic autoscaling, on ephemeral OS disks.
- Microsoft Entra joined session hosts, enrolled in Intune, with single sign-on and Conditional Access.
- Applications delivered with App Attach; FSLogix profile containers on Azure Files with Microsoft Entra Kerberos.
- Images built by Azure Image Builder and versioned in Azure Compute Gallery.
- Azure Monitor and AVD Insights from the first host pool.

Anything that can't meet the North Star yet runs as a [stepping stone](../docs/getting-there/stepping-stones.md) in its own host pool, with an owner and an exit plan. For example, applications that need Active Directory machine authentication run in a separate hybrid joined host pool.

When you help someone adapt the architecture, call out decisions that are fixed when a host pool is created, such as the host pool type and the management approach. Changing them means building a new host pool.

## Ground every Microsoft fact

- Check Microsoft and Azure facts on Microsoft Learn before you state them. Use the Microsoft Learn MCP server configured in `.vscode/mcp.json` when it's available. Don't answer version, syntax, limit or availability questions from memory.
- Link the learn.microsoft.com article for every technical claim, without a locale segment such as `/en-us/`.
- Quote cmdlets, parameters, resource properties, roles, settings and limits exactly as Learn writes them.
- Say whether a feature is generally available or in preview. Where older articles disagree, [What's new in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/whats-new) is the authority on status.
- If Learn doesn't confirm something, say so instead of guessing.

## Safety

- Never put secrets, keys, passwords, tenant or subscription IDs, or real organisation details in any file. Use the fictitious company Contoso in examples.
- Every script that changes something supports `-WhatIf`. Run with `-WhatIf` first, then against a test group or a non-production environment.
- Don't sign in to a tenant or run deployment, Azure or Microsoft Graph commands on someone's behalf unless they ask you to.
- A person reviews generated code, policy and templates before they're used. Say clearly what you haven't tested.

## Writing style

- Plain hyphens only. Never use an em dash or an en dash: the build fails on them (`scripts/check_style.py`).
- Australian English, plain words, short sentences. Contractions are fine.
- Documentation pages have YAML front matter with `title` and `description`, exactly one H1, an "At a glance" abstract, and Learn links inline. Mark feature status with `<span class="status ga">GA</span>` or `<span class="status preview">Preview</span>`.
- In Mermaid sequence diagrams, don't put quotes around participant aliases.

## Code conventions

- PowerShell 7.2 or later: `[CmdletBinding(SupportsShouldProcess)]` on anything that changes state, full comment-based help, `Set-StrictMode -Version Latest`, approved verbs, no aliases, and objects as output. Code must pass PSScriptAnalyzer. Pester tests live in each tool's `tests` folder.
- Bicep is the source for the deployment template. After you change `deploy/main.bicep` or a module, rebuild `deploy/azuredeploy.json` and keep every `createUiDefinition.json` output matched to a template parameter.
- Diagrams are generated from code in `scripts/diagrams/` using the official Azure and Microsoft Entra icons. Change the generator and rebuild, don't edit the SVG files by hand.
