# Azure Virtual Desktop North Star

[![Publish site](https://github.com/marckean/AVD-Reference_Architecture/actions/workflows/publish.yml/badge.svg)](https://github.com/marckean/AVD-Reference_Architecture/actions/workflows/publish.yml)

A reference architecture for modern Azure Virtual Desktop: what good looks like, how the pieces fit together, and how to get there from where you are today. Every recommendation links back to Microsoft Learn.

**Read it here: [marckean.github.io/AVD-Reference_Architecture](https://marckean.github.io/AVD-Reference_Architecture/)**

## What's inside

The home page is an overview of the whole reference architecture: what it is, the benefits, and a map of every area. The rest of the site is organised into groups, and each area has an overview page with subsections beneath it.

| Group | Areas |
| --- | --- |
| Overview | The home page, what good looks like (the North Star on one page) and how it fits together |
| Platform | Identity and access, host pools, scaling and images |
| Workloads and data | Applications with App Attach, user profiles with FSLogix, networking and security |
| Operations | Intune, monitoring, business continuity and cost optimisation |
| Getting there | A phased route, a dependency checklist with owners, and stepping stones for the parts of an estate that aren't ready yet |
| Reference | Glossary, an index of every Microsoft Learn article used, and notes about the site |

## The North Star in one line

Pooled host pools of Windows 11 Enterprise multi-session, run by a session host configuration with session host update and dynamic autoscaling, on ephemeral OS disks. Session hosts are Microsoft Entra joined and Intune managed, images come from Azure Image Builder and Azure Compute Gallery, applications arrive through App Attach, and FSLogix profiles live on Azure Files with Microsoft Entra Kerberos.

## Working on the site

The site is built with [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) and published to GitHub Pages by GitHub Actions on every push to `main`.

To preview it locally:

```bash
pip install -r requirements.txt
mkdocs serve
```

Then open `http://127.0.0.1:8000`.

The architecture diagram is an SVG generated from code. After changing `scripts/diagrams/build_north_star.py`, regenerate both theme variants with:

```bash
python scripts/diagrams/build_north_star.py
```

House rules for contributions:

- Ground every Microsoft or Azure technical claim in Microsoft Learn, and link it inline.
- Mark every recommended feature as generally available or preview.
- Quote setting, role and property names exactly.
- Keep it generic: use Contoso in examples.
- Use plain hyphens only. The build fails on em or en dashes (`scripts/check_style.py`).

## Disclaimer

This is a community reference architecture. It isn't official Microsoft guidance. Always confirm against the linked Microsoft Learn articles before you build.
