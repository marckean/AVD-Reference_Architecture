---
title: About this site
description: What this site is, how it's built and maintained, and the rules every page follows.
---

# About this site

!!! abstract "At a glance"
    - A community reference architecture for Azure Virtual Desktop. It describes what good looks like and how to get there.
    - It isn't official Microsoft guidance. Every claim links to the Microsoft Learn article it's based on.
    - It's built with Material for MkDocs and published to GitHub Pages by GitHub Actions on every change.

## Why it exists

Azure Virtual Desktop changed a lot through 2025 and 2026. Automated host pools, dynamic autoscaling, ephemeral OS disks, managed identities and cloud-only FSLogix all arrived in that time. The guidance is spread across many Microsoft Learn articles, and some older articles still describe these features as preview. This site brings them together into one target architecture, explains how the pieces fit, and is honest about where organisations need a stepping stone on the way.

## The rules every page follows

1. **Grounded in Microsoft Learn.** Every Microsoft or Azure technical claim links to the Learn article it comes from. Where Learn doesn't confirm something, the page says so in a *To verify* box rather than guessing.
2. **Status is explicit.** Every recommended feature is marked generally available or preview. Where older articles disagree with [What's new in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/whats-new), What's new is treated as the authority.
3. **Exact names.** Settings, roles, properties and limits are quoted exactly as Microsoft writes them, so you can search for them.
4. **Generic.** Examples use the fictitious company Contoso. Nothing on this site describes a real organisation's environment.
5. **Plain English.** Concepts are explained before they're used, for readers at level 200 to 400. The house style is Australian English with plain hyphens.

## Content currency

This version reflects Microsoft Learn as at **October 2026**. Azure Virtual Desktop updates often. Before you build, check the linked articles and [What's new in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/whats-new).

## How it's built

| Part | Detail |
| --- | --- |
| Source | Markdown in the `docs` folder of the [GitHub repository](https://github.com/marckean/AVD-Reference_Architecture) |
| Theme | Material for MkDocs |
| Diagrams | Mermaid, written as text in each page so they're easy to change |
| Publishing | A GitHub Actions workflow checks the house style, builds the site in strict mode and deploys it to GitHub Pages on every push to `main` |
| Changes | Use the edit icon at the top of any page, or open an issue or pull request on GitHub |

## Disclaimer

This site is provided as-is, for information. It isn't official Microsoft documentation and doesn't replace it. Designs and decisions remain the responsibility of the organisation that makes them. Always validate against the current Microsoft Learn articles and your own requirements before you build.

## Change history

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | October 2026 | First version: the North Star, eight architecture pillars, operations, the dependency checklist, stepping stones and the glossary |
