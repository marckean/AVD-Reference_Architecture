---
name: north-star-review
description: Review an Azure Virtual Desktop design, change or discovery output against the AVD North Star reference architecture in this repository - its target state, dependency checklist, decisions fixed at host pool creation, and stepping stones. Use when someone asks whether a design is aligned, what's missing, what can't be changed later, or which reference architecture pattern fits their situation.
argument-hint: "[design notes, a discovery export, or a question about the architecture]"
---

# Review a design against the North Star

Use the site content in [docs/](../../../docs/index.md) as the reference:

- [What good looks like](../../../docs/overview/what-good-looks-like.md) is the target state.
- The [dependency checklist](../../../docs/getting-there/dependencies.md) is the build order.
- [Stepping stones](../../../docs/getting-there/stepping-stones.md) covers the deliberate exceptions.

## What to check

1. **Decisions fixed at creation.** The host pool type and the management approach are set when a host pool is created and can't be changed afterwards ([Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches)). The session host configuration approach is for pooled host pools only. Flag any plan that assumes a conversion later.
2. **Identity per pool.** A session host configuration holds one domain join setting, so each pool has one join type. Applications that rely on machine authentication don't work on Microsoft Entra joined devices ([Device join plan](https://learn.microsoft.com/entra/identity/devices/device-join-plan#understand-considerations-for-applications-and-resources)), so they belong in a separate hybrid joined pool with an exit plan.
3. **Scaling.** Dynamic autoscaling needs a pooled host pool with a session host configuration, and the roles Learn lists at subscription scope ([Create and assign a scaling plan](https://learn.microsoft.com/azure/virtual-desktop/autoscale-create-assign-scaling-plan)). Ephemeral OS disk hosts can't be deallocated, so they're created and deleted.
4. **Dependencies.** Walk the dependency checklist layer by layer: licences and quota, identity, Intune, network, storage, image, host pool, applications, operations. List what's missing, and who usually owns it.
5. **Pattern fit.** Match the situation to a reference architecture pattern: the North Star, two host pools, personal desktops, RemoteApp, multi-region, or private connectivity.

## Output

Give a short verdict, then a table with these columns:

| Area | Finding | Why it matters | What to do | Learn source |
| --- | --- | --- | --- | --- |

End with the decisions that must be made before anything is built.

## Rules

- Ground every finding in Microsoft Learn, and say whether a feature is GA or preview.
- Separate facts from recommendations. Where Learn is silent, say so.
- Keep it generic. Don't add organisation names or details to repository files.
