---
title: "Skills transfer: teach the team"
description: A hands-on plan to make a small team self-sufficient in App Attach and MSIX. Three phases, five modules on your own packages, three roles, a six-week plan and clear ready-when checks.
---

# Skills transfer: teach the team

!!! abstract "At a glance"
    - **Learn on your own packages, not a lab.** Every module uses your real App-V packages and applications.
    - **Three phases: I do, we do, you do.** Watch, then pair, then lead while someone reviews.
    - **Five modules** take the team from the foundations to running packaging as a service.
    - **Three roles.** In a small team, one person can hold two.
    - **A clear finish line:** the team converts, signs, tests and onboards a package with no help.

## How it works

<span class="level l100">Level 100</span>

![Skills transfer in three phases. Phase 1, I do, watch us: module 1, foundations, covers how App Attach works, its formats, the share, registration and assignment; module 2, the fast lane, takes one of your App-V packages through App Attach end to end in a test host pool. Phase 2, we do, pair on your packages: module 3 converts App-V 5.1 to MSIX with the MSIX Packaging Tool, then signs it and makes the image; module 4 covers PSF fixups, the common errors, and testing a package outside Azure Virtual Desktop. Phase 3, you do, lead while we review: module 5 runs it as a service with bulk conversion, updates, rollback and retirement. You're ready when your team converts, signs, tests and onboards a package with no help. Three roles share the work: the platform engineer owns the share, permissions, App Attach and host pools; the packager owns the MSIX Packaging Tool, PSF fixups and signing; the tester and app owner own test scripts, real users and the sign-off. In a small team, one person can hold two roles.](../assets/images/app-attach-skills-path-light.svg#only-light)
![Skills transfer in three phases. Phase 1, I do, watch us: module 1, foundations, covers how App Attach works, its formats, the share, registration and assignment; module 2, the fast lane, takes one of your App-V packages through App Attach end to end in a test host pool. Phase 2, we do, pair on your packages: module 3 converts App-V 5.1 to MSIX with the MSIX Packaging Tool, then signs it and makes the image; module 4 covers PSF fixups, the common errors, and testing a package outside Azure Virtual Desktop. Phase 3, you do, lead while we review: module 5 runs it as a service with bulk conversion, updates, rollback and retirement. You're ready when your team converts, signs, tests and onboards a package with no help. Three roles share the work: the platform engineer owns the share, permissions, App Attach and host pools; the packager owns the MSIX Packaging Tool, PSF fixups and signing; the tester and app owner own test scripts, real users and the sign-off. In a small team, one person can hold two roles.](../assets/images/app-attach-skills-path-dark.svg#only-dark)

- **I do.** An expert drives and the team watches and asks. Modules 1 and 2.
- **We do.** The team drives, on its own packages, with the expert alongside. Modules 3 and 4.
- **You do.** The team leads and the expert reviews. Module 5.

## Three roles

<span class="level l100">Level 100</span>

| Role | Owns | Start with |
| --- | --- | --- |
| **Platform engineer** | The Azure Files share and its permissions, App Attach, host pools | [Manage user environments and apps for Azure Virtual Desktop](https://learn.microsoft.com/training/paths/manage-user-environments-apps/) (Learn training path) |
| **Packager** | The MSIX Packaging Tool, PSF fixups, signing, CimFS images | [Deploy applications by using MSIX app attach for Azure Virtual Desktop](https://learn.microsoft.com/training/modules/m365-wvd-application-management/) (Learn module, 7 units) |
| **Tester and app owner** | Test scripts, real users and the sign-off | The test checks in module 2 |

## Before module 1

<span class="level l200">Level 200</span>

- [ ] A test host pool. A proof of concept pool is ideal.
- [ ] An Azure Files share, set up as in [Requirements and file shares](requirements.md).
- [ ] A packaging virtual machine with the MSIX Packaging Tool and a clean checkpoint.
- [ ] A code signing certificate, or a test certificate for the first modules. See [Signing certificates, demystified](certificates.md).
- [ ] Three to five of your App-V packages: at least one rated Low, one Medium and one High (see [Rate your packages first](from-app-v.md#rate-your-packages-first)).
- [ ] A test user group, and time booked with two application owners.

## The five modules

<span class="level l200">Level 200</span>

### 1. Foundations

| | |
| --- | --- |
| **Goal** | Everyone shares the same picture. |
| **Hands-on** | Run the inventory and triage scripts over your App-V packages and your golden image, then read the results together. |
| **Toolkit** | `Get-AppVPackageInventory.ps1`, `Get-ImageApplicationInventory.ps1`, `Invoke-ApplicationTriage.ps1` |
| **Read first** | [Applications with App Attach](index.md) and the [Learn module](https://learn.microsoft.com/training/modules/m365-wvd-application-management/) |

**You're ready when:**

- [ ] Each person can explain App-V versus MSIX, staging versus registration, and why App-V packages need no signing.
- [ ] Every App-V package has a rating and an owner.

### 2. The fast lane

| | |
| --- | --- |
| **Goal** | Prove the platform with a package you already have. |
| **Hands-on** | Take one Low-rated App-V package through App Attach: copy it to the share, check the share, add and assign it, and test it with a real user. Then update it to a new version, and roll it back. |
| **Toolkit** | `Test-AppAttachShare.ps1`, `Add-AppAttachApplication.ps1` |
| **Read first** | [Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup) and [Requirements and file shares](requirements.md) |

**You're ready when:**

- [ ] The team onboards an App-V package without help.
- [ ] The team has updated a package and rolled it back.

### 3. Convert

| | |
| --- | --- |
| **Goal** | Turn an App-V package into a signed MSIX image. |
| **Hands-on** | Convert a Low-rated package with the MSIX Packaging Tool, sign it with a timestamp, make the CimFS image, and add it to App Attach. Then do a Medium-rated one. |
| **Toolkit** | `New-MsixConversionTemplate.ps1`, `New-AppAttachImage.ps1` |
| **Read first** | [From App-V to App Attach and MSIX](from-app-v.md), [Packaging, step by step](packages.md) and [Signing certificates, demystified](certificates.md) |

**You're ready when:**

- [ ] The team has converted, signed, imaged and onboarded two packages.
- [ ] The publisher matches the certificate first time.

### 4. Fix and troubleshoot

| | |
| --- | --- |
| **Goal** | Handle the packages that don't just work. |
| **Hands-on** | Take a High-rated package: work through the services report, add context menus and PSF fixups, then test it outside Azure Virtual Desktop by staging and registering it on one machine. Read the logs on purpose, not only when something breaks. |
| **Toolkit** | The Package Editor and its **PSF Fixups** tab, and the test scripts in [Test MSIX packages for App Attach](https://learn.microsoft.com/azure/virtual-desktop/app-attach-test-msix-packages) |
| **Read first** | [Troubleshooting](troubleshooting.md) and the [MSIX troubleshooting guide](https://learn.microsoft.com/windows/msix/msix-troubleshooting-guide) |

**You're ready when:**

- [ ] The team fixes a publisher mismatch and an untrusted certificate on their own.
- [ ] The team can tell whether a fault is in the package, the share or the assignment.

### 5. Run it as a service

| | |
| --- | --- |
| **Goal** | A repeatable pipeline, not a project. |
| **Hands-on** | Convert a batch of five to ten packages from templates on the command line. Version, update, roll back and retire them. Agree a definition of done for every package. |
| **Toolkit** | `New-MsixConversionTemplate.ps1` and the [MSIX Toolkit bulk conversion scripts](https://learn.microsoft.com/windows/msix/toolkit/msix-toolkit-msixbatchconversion) |
| **Read first** | [Conversion with the command line](https://learn.microsoft.com/windows/msix/packaging-tool/package-conversion-command-line) and the [App Attach fast track](../accelerators/app-attach-fast-track.md) |

**You're ready when:**

- [ ] The team runs a batch end to end, and the expert only reviews.
- [ ] Every new application request follows one intake and sign-off route.

All the scripts are in [`tools/app-attach`](https://github.com/marckean/AVD-Reference_Architecture/tree/main/tools/app-attach).

## A six-week plan

<span class="level l200">Level 200</span>

| Week | Phase | Sessions | By the end |
| --- | --- | --- | --- |
| 1 | I do | Module 1: two sessions of two hours | One shared picture, and every App-V package rated |
| 2 | I do | Module 2: two sessions of two hours | The first App-V package live for a test group |
| 3 | We do | Module 3: two sessions, plus practice | Two MSIX packages signed and onboarded by the team |
| 4 | We do | Module 4: two sessions, plus practice | A hard package fixed, and faults diagnosed by the team |
| 5 and 6 | You do | Module 5: one review a week | A batch converted and onboarded by the team |

Stretch it if application owners can't test that quickly. Their time, not the tooling, usually sets the pace.

## Making it stick

<span class="level l300">Level 300</span>

- **A definition of done for every package:** inventory row and rating, template, signed MSIX, CimFS image, test result, owner sign-off, assignment and rollback plan.
- **One intake route** for new applications and updates, so nothing bypasses packaging.
- **A runbook** for the common faults. Start from [Troubleshooting](troubleshooting.md) and add your own.
- **Pair across roles,** so no single person holds the knowledge.
- **Share the tool settings.** The MSIX Packaging Tool can export and import its settings, so every packager works the same way ([Best practices](https://learn.microsoft.com/windows/msix/packaging-tool/tool-best-practices)).
- **Let AI do the typing.** GitHub Copilot, with this repository's instructions and the Microsoft Learn MCP server, can draft templates, explain errors and write test scripts. People still decide, sign and approve. See [Working with AI](../accelerators/working-with-ai.md).
- **Measure it:** packages per week, how many work first time, time to fix a fault, and how often the team needs to escalate.

## Why this order works

<span class="level l300">Level 300</span>

- **The fast lane comes before conversion.** It proves the share, permissions and assignments with a package that already works, so a later fault can't be blamed on the platform.
- **Conversion comes before troubleshooting.** The team meets real errors on easy packages first, and then on hard ones.
- **Running it as a service comes last,** when the team has seen enough to write its own runbook.

## Under the hood

<span class="level l400">Level 400</span>

What each module exercises in the platform:

- **Module 2** exercises the share permissions that every session host uses to mount images, and the registration modes, **On-demand** and **Log on blocking** ([App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)).
- **Module 3** exercises package identity. The manifest publisher must match the signing certificate's subject exactly ([MSIX troubleshooting guide](https://learn.microsoft.com/windows/msix/msix-troubleshooting-guide)).
- **Module 4** exercises the MSIX container: redirected file and registry writes, and the PSF fixups that bridge them ([PSF overview](https://learn.microsoft.com/windows/msix/psf/package-support-framework-overview)).
- **Module 5** exercises versioning. App Attach won't update an application to the same version number, and the old image should stay until nobody is using it ([App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)).

## Microsoft Learn

- [Manage user environments and apps for Azure Virtual Desktop](https://learn.microsoft.com/training/paths/manage-user-environments-apps/) (training path)
- [Deploy applications by using MSIX app attach for Azure Virtual Desktop](https://learn.microsoft.com/training/modules/m365-wvd-application-management/) (training module)
- [Install and configure apps on a session host](https://learn.microsoft.com/training/modules/install-configure-apps-session-host/) (training module)
- [Study guide for Exam AZ-140](https://learn.microsoft.com/credentials/certifications/resources/study-guides/az-140)
- [MSIX Packaging Tool overview](https://learn.microsoft.com/windows/msix/packaging-tool/tool-overview)
- [Conversion with the command line](https://learn.microsoft.com/windows/msix/packaging-tool/package-conversion-command-line)
- [MSIX bulk conversion scripts](https://learn.microsoft.com/windows/msix/toolkit/msix-toolkit-msixbatchconversion)
- [Test MSIX packages for App Attach](https://learn.microsoft.com/azure/virtual-desktop/app-attach-test-msix-packages)
- [Add and manage App Attach applications](https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup)

---

Part of [Applications with App Attach](index.md).
