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
5. **Plain English, then depth.** Every area starts in plain terms and goes deeper step by step, from Level 100 to Level 400, so a newcomer and an expert can both use the same page. Concepts are explained before they're used. The house style is Australian English with plain hyphens.

## Reading levels

Pages mark where each level starts, so you can stop when you have what you need or skip ahead to the depth you want.

| Level | What you get |
| --- | --- |
| <span class="level l100">Level 100</span> | **In plain terms.** What it is and why it matters, with an everyday analogy and no jargon. No Azure Virtual Desktop background needed. |
| <span class="level l200">Level 200</span> | **How it works.** The components, how they connect and the main flow. |
| <span class="level l300">Level 300</span> | **Design.** Decisions, configuration, requirements, trade-offs and limits. |
| <span class="level l400">Level 400</span> | **Under the hood.** Internals, protocols, exact limits, edge cases, and troubleshooting with exact commands, event IDs and log queries. |

Area overview pages run through all four levels. Subsection pages show their main level under the summary at the top. The [Identity demystified](../demystified/index.md) series takes one topic, identity and authentication, from Level 100 to Level 400 across eight pages.

## Content currency

This version reflects Microsoft Learn as at **October 2026**. Azure Virtual Desktop updates often. Before you build, check the linked articles and [What's new in Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/whats-new).

## How it's built

| Part | Detail |
| --- | --- |
| Source | Markdown in the `docs` folder of the [GitHub repository](https://github.com/marckean/AVD-Reference_Architecture) |
| Theme | Material for MkDocs |
| Diagrams | Two kinds. Architecture diagrams are SVGs built from the official icons by `scripts/diagrams/build_all.py`, in light and dark versions that follow the site theme. A layout check fails the build if any text, card, panel or badge overlaps or doesn't fit. Flows and sequences are Mermaid, written as text in each page so they're easy to change, and checked for readability at the site's content width |
| Icons | The architecture diagram uses the official [Azure architecture icons](https://learn.microsoft.com/azure/architecture/icons/) and [Microsoft Entra architecture icons](https://learn.microsoft.com/entra/architecture/architecture-icons), which Microsoft permits in architectural diagrams, training materials and documentation |
| Publishing | A GitHub Actions workflow checks the house style, builds the site in strict mode and deploys it to GitHub Pages on every push to `main` |
| Changes | Use the edit icon at the top of any page, or open an issue or pull request on GitHub |

## Disclaimer

This site is provided as-is, for information. It isn't official Microsoft documentation and doesn't replace it. Designs and decisions remain the responsibility of the organisation that makes them. Always validate against the current Microsoft Learn articles and your own requirements before you build.

## Change history

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | October 2026 | First version: the North Star, eight architecture pillars, operations, the dependency checklist, stepping stones and the glossary |
| 0.2 | October 2026 | Reorganised into an overview and twelve areas, each with an overview page and subsections. Added the architecture diagram with official icons, and replaced the open "To verify" items with verified Microsoft Learn facts |
| 0.3 | October 2026 | Added the reference architectures gallery, the dependency map, icon diagrams across the areas, and the accelerators: a discovery questionnaire, a Deploy to Azure wizard tested in a live deployment, the App Attach fast track, Intune policy examples and AI assistance |
| 0.4 | October 2026 | Added reading levels from 100 to 400 across every area, the Identity demystified series, the sizing estimates page, and more diagrams. Made the diagram layout check stricter and resized the diagrams to fit |
