"""Build all SVG architecture diagrams for the AVD reference architecture site."""

from __future__ import annotations

from pathlib import Path

from svgkit import OUT, Svg, scrub


W = 1000

LEARN = {
    "licensing": "https://learn.microsoft.com/azure/virtual-desktop/licensing",
    "quotas": "https://learn.microsoft.com/azure/quotas/view-quotas",
    "host_pool_management": "https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches",
    "autoscale": "https://learn.microsoft.com/azure/virtual-desktop/autoscale-scenarios",
    "session_host_update": "https://learn.microsoft.com/azure/virtual-desktop/session-host-update",
    "ephemeral": "https://learn.microsoft.com/azure/virtual-desktop/deploy/session-hosts/ephemeral-os-disks",
    "entra_hosts": "https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts",
    "device_join": "https://learn.microsoft.com/entra/identity/devices/device-join-plan",
    "sso": "https://learn.microsoft.com/azure/virtual-desktop/configure-single-sign-on",
    "mfa": "https://learn.microsoft.com/azure/virtual-desktop/set-up-mfa",
    "kerberos_files": "https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable",
    "files_identity": "https://learn.microsoft.com/azure/storage/files/storage-files-active-directory-overview",
    "fslogix_store": "https://learn.microsoft.com/azure/virtual-desktop/store-fslogix-profile",
    "files_scale": "https://learn.microsoft.com/azure/storage/files/storage-files-scale-targets",
    "intune": "https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session",
    "managed_identity": "https://learn.microsoft.com/azure/virtual-desktop/configure-managed-identity",
    "app_attach": "https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview",
    "app_attach_setup": "https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup",
    "app_attach_image": "https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image",
    "msix_tool": "https://learn.microsoft.com/windows/msix/packaging-tool/create-app-package",
    "msix_sign": "https://learn.microsoft.com/windows/msix/package/signing-package-overview",
    "msix_intune": "https://learn.microsoft.com/windows/msix/desktop/managing-your-msix-deployment-intune",
    "w365_apps": "https://learn.microsoft.com/windows-365/enterprise/app-overview",
    "w365_images": "https://learn.microsoft.com/windows-365/enterprise/device-images",
    "service_principal": "https://learn.microsoft.com/azure/virtual-desktop/service-principal-assign-roles",
    "image_builder": "https://learn.microsoft.com/azure/virtual-machines/image-builder-overview",
    "compute_gallery": "https://learn.microsoft.com/azure/virtual-machines/azure-compute-gallery",
    "private_link": "https://learn.microsoft.com/azure/virtual-desktop/private-link-overview",
    "rdp_shortpath": "https://learn.microsoft.com/azure/virtual-desktop/rdp-shortpath",
    "network": "https://learn.microsoft.com/azure/virtual-desktop/network-connectivity",
    "insights": "https://learn.microsoft.com/azure/virtual-desktop/insights",
    "diagnostics": "https://learn.microsoft.com/azure/virtual-desktop/diagnostics-log-analytics",
    "ama": "https://learn.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-overview",
    "security": "https://learn.microsoft.com/azure/virtual-desktop/security-recommendations",
    "regional": "https://learn.microsoft.com/azure/virtual-desktop/regional-host-pools",
    "backup": "https://learn.microsoft.com/azure/backup/azure-file-share-backup-overview",
    "hybrid_identity": "https://learn.microsoft.com/entra/identity/hybrid/whatis-hybrid-identity",
    "entra_what_is": "https://learn.microsoft.com/entra/fundamentals/whatis",
    "cloud_sync": "https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/what-is-cloud-sync",
    "ad_ds": "https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview",
    "identity_platform": "https://learn.microsoft.com/entra/identity-platform/v2-overview",
    "device_overview": "https://learn.microsoft.com/entra/identity/devices/overview",
    "device_registered": "https://learn.microsoft.com/entra/identity/devices/concept-device-registration",
    "concept_join": "https://learn.microsoft.com/entra/identity/devices/concept-directory-join",
    "hybrid_join": "https://learn.microsoft.com/entra/identity/devices/concept-hybrid-join",
    "prt": "https://learn.microsoft.com/entra/identity/devices/concept-primary-refresh-token",
    "device_sso_onprem": "https://learn.microsoft.com/entra/identity/devices/device-sso-to-on-premises-resources",
    "cloud_kerberos_trust": "https://learn.microsoft.com/windows/security/identity-protection/hello-for-business/deploy/hybrid-cloud-kerberos-trust",
    "passwordless_onprem": "https://learn.microsoft.com/entra/identity/authentication/howto-authentication-passwordless-security-key-on-premises",
}


manifest: list[dict[str, object]] = []


def add_manifest(name: str, page: str, section: str, alt: str, steps: list[str] | None, urls: list[str], nodes: list[tuple[int, str, str]] | None = None) -> None:
    manifest.append(
        {
            "name": name,
            "page": page,
            "section": section,
            "alt": scrub(alt),
            "steps": [scrub(s) for s in (steps or [])],
            "urls": urls,
            "nodes": nodes or [],
        }
    )


def north_star(mode: str) -> Svg:
    s = Svg(W, 564, mode, "Azure Virtual Desktop North Star architecture", "Users sign in with Microsoft Entra ID and connect through Azure Virtual Desktop. A pooled host pool of Microsoft Entra joined session hosts on ephemeral OS disks is created and updated by session host configuration and autoscale, uses images from Azure Compute Gallery and policy from Microsoft Intune, reads profiles and App Attach packages from Azure Files over a private endpoint, and sends telemetry to Azure Monitor.")
    p = s.p
    s.icon("users", 52, 192, 52)
    s.text(78, 270, "Users", size=14, weight=600, colour=p["title"], anchor="middle")
    s.text(78, 288, "Windows App or", anchor="middle")
    s.text(78, 304, "web browser", anchor="middle")
    s.panel(168, 24, 318, 520, "Microsoft-managed services", "panel_ms")
    s.card(186, 66, 282, 92, "entra-id", "Microsoft Entra ID", ["Sign-in, Conditional Access", "and single sign-on"])
    s.rect(186, 180, 282, 178, *p["card"], rx=8, width=1)
    s.icon("avd", 200, 198, 38)
    s.text(250, 212, "Azure Virtual Desktop", size=14, weight=600, colour=p["title"])
    s.text(250, 232, "Workspace feed, gateway")
    s.text(250, 248, "and broker")
    s.line(250, 266, 452, 266, colour=p["divider"], width=1)
    s.text(250, 288, "Session host configuration,")
    s.text(250, 304, "session host update and")
    s.text(250, 320, "autoscale")
    s.card(186, 380, 282, 92, "intune", "Microsoft Intune", ["Device and user policy from", "the settings catalog"])
    s.panel(516, 24, 468, 520, "Your Azure subscription", "panel_sub")
    s.rect(534, 62, 432, 240, "none", p["vnet"], rx=8, dash="6 4", width=1.3)
    s.icon("vnet", 548, 70, 18)
    s.text(572, 84, "Spoke virtual network", size=12, weight=600, colour=p["title"])
    s.rect(552, 98, 236, 188, *p["card"], rx=8, width=1)
    s.icon("host-pools", 566, 112, 36)
    s.text(612, 126, "Pooled host pool", size=14, weight=600, colour=p["title"])
    s.text(612, 144, "Windows 11 Enterprise")
    s.text(612, 160, "multi-session")
    for i in range(3):
        s.icon("vm", 605 + i * 48, 176, 34)
    s.text(670, 236, "Microsoft Entra joined session", anchor="middle")
    s.text(670, 252, "hosts on ephemeral OS disks", anchor="middle")
    s.rect(826, 156, 124, 72, *p["card"], rx=8, width=1)
    s.icon("private-endpoint", 873, 164, 30)
    s.text(888, 214, "Private endpoint", size=12, anchor="middle")
    s.card(534, 336, 214, 110, "gallery", "Azure Compute Gallery", ["Image versions built by", "Azure Image Builder"], title_size=12)
    s.card(770, 336, 196, 110, "files", "Azure Files", ["FSLogix profiles and", "App Attach packages"], title_size=13)
    s.rect(534, 468, 432, 66, *p["card"], rx=8, width=1)
    s.icon("monitor", 548, 484, 34)
    s.text(594, 498, "Azure Monitor and Log Analytics", size=13, weight=600, colour=p["title"])
    s.text(594, 517, "Diagnostics, performance data, AVD Insights and alerts")
    s.arrow([(110, 214), (140, 214), (140, 112), (183, 112)])
    s.arrow([(110, 240), (183, 240)])
    s.arrow([(550, 140), (500, 140), (500, 222), (471, 222)])
    s.arrow([(788, 192), (823, 192)])
    s.arrow([(888, 228), (888, 336)])
    s.arrow([(468, 300), (510, 300), (510, 250), (549, 250)])
    s.arrow([(640, 336), (640, 289)])
    s.arrow([(468, 426), (524, 426), (524, 272), (549, 272)])
    s.arrow([(760, 286), (760, 465)])
    # Badges 6 and 8 sit in the clear band between the spoke's dashed border (y 302) and the cards below (y 336).
    for cx, cy, n in [(140, 166, 1), (152, 240, 2), (500, 182, 3), (888, 268, 4), (500, 284, 5), (640, 319, 6), (500, 372, 7), (760, 319, 8)]:
        s.badge(cx, cy, str(n))
    return s


def two_host_pools(mode: str) -> Svg:
    s = Svg(W, 650, mode, "Two host pools for North Star and legacy applications", "One workspace publishes a Microsoft Entra joined North Star pooled host pool and a separate hybrid joined pooled host pool for legacy applications that need AD DS dependencies.")
    p = s.p
    s.icon("users", 42, 275, 54)
    s.text(69, 348, "Users", size=14, weight=700, colour=p["title"], anchor="middle")
    s.panel(150, 45, 245, 545, "Microsoft-managed services", "panel_ms")
    s.card(172, 83, 200, 94, "entra-id", "Microsoft Entra ID", "Sign-in and SSO")
    s.card(172, 225, 200, 96, "workspace", "One workspace", "One feed for both pools")
    s.card(172, 370, 200, 96, "application-group", "Application groups", "User assignments")
    s.panel(430, 45, 520, 510, "Your Azure subscription", "panel_sub")
    s.rect(455, 92, 455, 455, "none", p["vnet"], rx=10, dash="6 4")
    s.text(477, 116, "Spoke virtual network", size=12, weight=700, colour=p["title"])
    s.card(480, 145, 195, 150, "host-pools", "North Star pooled pool", ["Entra joined", "Intune managed", "Dynamic autoscale"], number=1)
    s.card(700, 145, 185, 150, "host-pools", "Legacy pooled pool", ["Hybrid joined", "AD DS dependency"], number=2, fixed=True)
    s.card(480, 330, 195, 105, "files", "North Star storage", ["Azure Files", "Entra Kerberos"])
    s.card(700, 330, 185, 105, "storage-account", "Legacy storage access", ["Separate model", "Per app need"])
    s.card(482, 448, 185, 84, "compute-gallery", "Clean image", "Marketplace base")
    s.card(700, 448, 185, 84, "images", "Legacy image track", "Separate path")
    s.panel(430, 570, 520, 145, "Identity infrastructure", "panel_alt")
    s.card(450, 610, 145, 84, "domain-services", "AD DS DCs", "Line of sight", title_size=11, body_size=11)
    s.card(615, 610, 170, 84, "entra-id-official", "Connect or Cloud Sync", "Hybrid IDs", title_size=12)
    s.card(790, 610, 145, 84, "groups", "Assignments", "Apps", title_size=12)
    s.arrow([(95, 302), (140, 302), (140, 273), (172, 273)])
    s.arrow([(272, 177), (272, 225)])
    s.arrow([(372, 274), (430, 274), (430, 210), (480, 210)])
    s.arrow([(372, 274), (430, 274), (430, 128), (792, 128), (792, 145)])
    s.arrow([(272, 321), (272, 370)])
    s.arrow([(372, 418), (430, 418), (430, 254), (480, 254)], dashed=True)
    for n, x, y in [(1, 450, 210), (2, 792, 125), (3, 408, 274)]:
        s.badge(x, y, str(n))
    return s


def personal_desktops(mode: str) -> Svg:
    s = Svg(W, 640, mode, "Personal desktop options", "Dedicated persistent desktops use either a personal host pool with standard management or Windows 365 Cloud PCs, while the pooled North Star remains the default for most users.")
    p = s.p
    s.icon("users", 52, 276, 56)
    s.text(80, 350, "Users", size=14, weight=700, colour=p["title"], anchor="middle")
    s.panel(155, 58, 255, 500, "Microsoft-managed services", "panel_ms")
    s.card(180, 95, 205, 95, "entra-id", "Microsoft Entra ID", "Sign-in and CA")
    s.card(180, 245, 205, 95, "avd", "Azure Virtual Desktop", "Brokers desktops")
    s.card(180, 395, 205, 95, "intune", "Microsoft Intune", "Policy for both options")
    s.panel(445, 58, 495, 500, "Dedicated desktop choices", "panel_sub")
    s.card(475, 100, 190, 150, "host-pools", "Personal host pool", ["Standard mgmt", "Assigned", "Power mgmt"], number=1, fixed=True)
    s.card(710, 100, 190, 150, None, "Windows 365 Cloud PC", ["Dedicated Cloud PC", "Managed with Intune"], number=2)
    s.card(475, 300, 190, 115, "disks", "Persistent OS disk", ["User changes persist", "Not disposable"])
    s.card(710, 300, 190, 115, "files", "Profile model differs", ["FSLogix may not", "be required"])
    s.card(595, 455, 190, 84, "compute-gallery", "Keep the pool small", "Review often")
    s.arrow([(108, 304), (140, 304), (140, 142), (180, 142)])
    s.arrow([(385, 292), (430, 292), (430, 176), (475, 176)])
    s.arrow([(385, 292), (430, 292), (430, 40), (805, 40), (805, 100)])
    s.arrow([(570, 250), (570, 300)])
    s.arrow([(805, 250), (805, 300)])
    s.arrow([(570, 415), (570, 442), (650, 442), (650, 455)], dashed=True)
    s.arrow([(805, 415), (805, 442), (735, 442), (735, 455)], dashed=True)
    for n, x, y in [(1, 462, 176), (2, 805, 76), (3, 650, 442)]:
        s.badge(x, y, str(n))
    return s


def remoteapp(mode: str) -> Svg:
    s = Svg(W, 640, mode, "RemoteApp and desktop from one pooled host pool", "A pooled host pool can publish a desktop application group and a RemoteApp application group. App Attach assigns applications to the host pool and to user groups.")
    p = s.p
    s.icon("users", 50, 280, 56)
    s.text(78, 352, "Users", size=14, weight=700, colour=p["title"], anchor="middle")
    s.panel(145, 70, 260, 455, "Publishing layer", "panel_ms")
    s.card(170, 108, 210, 86, "workspace", "Workspace", "One feed")
    s.card(170, 250, 210, 92, "application-group", "Desktop group", "Full desktop", number=1)
    s.card(170, 390, 210, 92, "application-group", "RemoteApp group", "Selected apps", number=2)
    s.panel(445, 70, 495, 455, "Pooled host pool", "panel_sub")
    s.card(475, 120, 205, 130, "host-pools", "Windows 11 multi-session", ["One pooled host pool", "Two app groups"])
    s.card(710, 120, 190, 130, "files", "App Attach share", ["MSIX, Appx or", "App-V packages"])
    s.card(475, 315, 205, 105, "avd", "User sessions", ["Desktop or", "RemoteApp"])
    s.card(710, 315, 190, 105, "groups", "User or group", "Application assignment")
    s.arrow([(106, 306), (130, 306), (130, 151), (170, 151)])
    s.arrow([(275, 194), (275, 250)])
    s.arrow([(275, 342), (275, 390)])
    s.arrow([(380, 296), (420, 296), (420, 185), (475, 185)])
    s.arrow([(380, 436), (420, 436), (420, 215), (475, 215)])
    s.arrow([(805, 250), (805, 315)])
    s.arrow([(710, 370), (680, 370)])
    s.arrow([(710, 184), (680, 184)])
    for n, x, y in [(1, 420, 296), (2, 420, 436), (3, 805, 287), (4, 695, 184)]:
        s.badge(x, y, str(n))
    return s


def multi_region(mode: str) -> Svg:
    s = Svg(W, 650, mode, "Multi-region resilience pattern", "Primary and secondary regions protect the state that matters: profiles, packages, images, configuration and monitoring. Pooled session hosts are rebuilt rather than replicated.")
    p = s.p
    s.panel(60, 72, 395, 475, "Primary region", "panel_sub")
    s.panel(545, 72, 395, 475, "Secondary region", "panel_sub")
    primary_hp = s.card(90, 122, 155, 100, "host-pools", "Primary host pool", "Regional pool", title_size=12.5)
    primary_hosts = s.card(275, 122, 145, 100, "vm", "Session hosts", "Rebuilt")
    primary_profiles = s.card(90, 265, 155, 100, "files", "Profiles", "Protected share")
    primary_apps = s.card(275, 265, 145, 100, "files", "App packages", "Replicated share")
    primary_images = s.card(170, 410, 170, 100, "compute-gallery", "Image versions", "Replicated versions")
    secondary_hp = s.card(575, 122, 155, 100, "host-pools", "Passive host pool", "Regional pool", title_size=12.5)
    secondary_hosts = s.card(760, 122, 145, 100, "vm", "Session hosts", "Rebuilt")
    secondary_profiles = s.card(575, 265, 155, 100, "files", "Profiles", "Protected share")
    secondary_apps = s.card(760, 265, 145, 100, "files", "App packages", "Replicated share")
    secondary_images = s.card(655, 410, 170, 100, "compute-gallery", "Image versions", "Replicated versions")
    iac = s.card(380, 570, 240, 74, "resource-group", "Infrastructure as code", "Rebuilds the platform")
    s.h_arrow(primary_hp, primary_hosts)
    s.h_arrow(secondary_hp, secondary_hosts)
    s.arrow([(245, 315), (245, 385), (575, 385), (575, 315)], dashed=True, source=primary_profiles, target=secondary_profiles, label="profiles")
    s.arrow([(420, 315), (420, 390), (760, 390), (760, 315)], dashed=True, source=primary_apps, target=secondary_apps, label="apps")
    s.h_arrow(primary_images, secondary_images, dashed=True)
    s.arrow([(500, 570), (500, 535), (255, 535), (255, 510)], dashed=True, source=iac, target=primary_images, label="iac-primary")
    s.arrow([(500, 570), (500, 535), (740, 535), (740, 510)], dashed=True, source=iac, target=secondary_images, label="iac-secondary")
    s.badge(500, 385, "1")
    s.badge(500, 460, "2")
    s.badge(500, 535, "3")
    return s


def private_connectivity(mode: str) -> Svg:
    s = Svg(W, 650, mode, "Private and public connectivity paths", "Azure Virtual Desktop uses reverse connect by default, can use Private Link for private service access, and can use RDP Shortpath over managed networks or public STUN and TURN paths.")
    p = s.p
    s.panel(40, 70, 260, 500, "Client networks", "panel_sub")
    s.card(68, 120, 200, 90, "users", "Managed network users", "ExpressRoute or VPN")
    s.card(68, 310, 200, 90, "users", "Internet users", "Public client path")
    s.card(80, 455, 175, 84, "expressroute", "ExpressRoute or VPN", "Private path")
    s.panel(355, 70, 250, 470, "Microsoft-managed services", "panel_ms")
    s.card(382, 120, 195, 110, "private-link", "AVD Private Link", "Private service access")
    s.card(382, 300, 195, 95, "avd", "AVD gateway and broker", "Reverse connect")
    s.panel(660, 70, 285, 470, "Hub and spoke Azure", "panel_sub")
    s.card(685, 110, 105, 82, "azure-firewall", "Hub", "DNS", title_size=12)
    s.card(812, 110, 105, 82, "vnet", "Spoke", "Hosts", title_size=12)
    spoke = s.panel(690, 230, 230, 280, "Session host spoke", "panel_alt", dashed=True)
    session_hosts = s.card(710, 280, 185, 82, "host-pools", "Session hosts", "Outbound only", parent=spoke)
    storage = s.card(710, 390, 185, 84, "private-endpoint", "Azure Files", "Private endpoint", parent=spoke)
    s.arrow([(268, 165), (382, 165)], dashed=True)
    s.arrow([(268, 355), (382, 355)])
    s.arrow([(480, 230), (480, 300)])
    s.arrow([(577, 348), (660, 348), (660, 322), (710, 322)])
    s.arrow([(255, 490), (690, 490)], dashed=True)
    s.arrow([(268, 165), (330, 165), (330, 265), (760, 265), (760, 280)], dashed=True)
    s.arrow([(765, 362), (765, 390)], source=session_hosts, target=storage, label="5")
    s.badge(318, 165, "1")
    s.badge(318, 355, "2")
    s.badge(635, 348, "3")
    s.badge(632, 490, "4")
    s.badge(765, 376, "5")
    return s


DEPENDENCY_NODES = [
    (1, "Licences and quota", "Users, region and capacity."),
    (2, "Identity", "Microsoft Entra ID. AD DS only where needed."),
    (3, "Network", "Outbound and private paths."),
    (4, "Host pool type", "Pooled or personal.",),
    (5, "Management approach", "Standard or SHC.",),
    (6, "Domain join type", "One type per pool.",),
    (7, "Host config", "MI and Key Vault."),
    (8, "Session update", "Batch replace."),
    (9, "Dynamic autoscale", "Create and delete."),
    (10, "Ephemeral OS disks", "Create and delete only."),
    (11, "Single sign-on", "Entra auth."),
    (12, "FSLogix profiles", "SMB and RBAC."),
    (13, "App Attach", "Share and SP roles."),
    (14, "Intune policy", "Settings catalog."),
    (15, "Legacy auth", "Use a hybrid pool."),
]


def dependency_map(mode: str) -> Svg:
    s = Svg(W, 820, mode, "Azure Virtual Desktop dependency map", "A layered dependency map for the North Star showing fixed-at-creation decisions, hard requirements and recommended relationships.")
    p = s.p
    dep_panel = s.panel(35, 35, 930, 820, "Master dependency map", "panel_sub")
    coords = {
        1: (65, 75),
        2: (390, 75),
        3: (715, 75),
        4: (65, 225),
        5: (390, 225),
        6: (715, 225),
        7: (50, 375),
        8: (280, 375),
        9: (520, 375),
        10: (760, 375),
        11: (50, 540),
        12: (232, 540),
        13: (414, 540),
        14: (596, 540),
        15: (778, 540),
    }
    icons = {1: "resource-group", 2: "entra-id", 3: "vnet", 4: "host-pools", 5: "host-pools", 6: "entra-id-official", 7: "key-vault", 8: "compute-gallery", 9: "avd", 10: "disks", 11: "entra-id-official", 12: "files", 13: "application-group", 14: "intune", 15: "domain-services"}
    fixed = {4, 5, 6}
    names: dict[int, str] = {}
    for num, title, body in DEPENDENCY_NODES:
        x, y = coords[num]
        w = 220 if num in {1, 2, 3, 4, 5, 6} else 170
        h = 100 if num not in {11, 12, 13, 14, 15} else 105
        names[num] = s.card(x, y, w, h, icons[num], title, body, number=num, fixed=num in fixed, title_size=12.2, body_size=11, parent=dep_panel)
    # Every relationship below is grounded in Microsoft Learn and explained on docs/overview/dependency-map.md.
    # Each source has its own route, so no line is shared by two different sources.
    def route(a: int, b: int, points: list[tuple[float, float]], dashed: bool = False) -> None:
        s.arrow(points, dashed=dashed, colour=p["recommended"] if dashed else p["requires"], source=names[a], target=names[b], label=f"{a}->{b}")

    def drop(a: int, b: int, bus_y: float) -> None:
        start = s.edge_point(names[a], "bottom")
        end = s.edge_point(names[b], "top")
        route(a, b, [start, (start[0], bus_y), (end[0], bus_y), end])

    # Foundations feed the decisions that are fixed when the host pool is created.
    drop(1, 4, 200)
    drop(3, 6, 200)
    drop(2, 6, 200)
    # The session host configuration approach can be used with pooled host pools only.
    route(4, 5, [s.edge_point(names[4], "right"), s.edge_point(names[5], "left")])
    # The management approach decides the whole host pool engine row.
    for b in (7, 8, 9, 10):
        drop(5, b, 350)
    # Learn recommends dynamic autoscaling for host pools with ephemeral OS disks.
    route(10, 9, [s.edge_point(names[10], "left"), s.edge_point(names[9], "right")], dashed=True)
    # The domain join type decides how single sign-on, profiles, App Attach, Intune and legacy applications work.
    trunk_start = s.edge_point(names[6], "right")
    for b in (15, 14, 13, 12, 11):
        end = s.edge_point(names[b], "top")
        route(6, b, [trunk_start, (950, trunk_start[1]), (950, 515), (end[0], 515), end])
    # Intune delivers the Kerberos ticket retrieval and FSLogix settings.
    start = s.edge_point(names[14], "bottom")
    end = s.edge_point(names[12], "bottom")
    route(14, 12, [start, (start[0], 668), (end[0], 668), end], dashed=True)
    s.legend(70, 740, [("solid", "Requires"), ("dashed", "Works with or recommended"), ("fixed", "Fixed at host pool creation")])
    s.label(365, 744, "Fixed choices are not conversion targets. Moving later means a new host pool.", 300, size=11.8)
    return s


def identity_flow(mode: str) -> Svg:
    s = Svg(W, 640, mode, "Identity and sign-in flow", "Users sign in through Microsoft Entra ID, Conditional Access evaluates the launch, single sign-on signs in to the session host, and Microsoft Entra Kerberos gives access to Azure Files.")
    p = s.p
    s.icon("users", 55, 278, 54)
    s.text(82, 350, "User", size=14, weight=700, colour=p["title"], anchor="middle")
    cards = [
        (160, 120, "entra-id", "Microsoft Entra ID", "User auth"),
        (360, 120, "policy", "CA policy", "AVD and WCL"),
        (560, 120, "avd", "AVD broker", "Workspace access"),
        (760, 120, "vm", "Host sign-in", "Entra SSO"),
        (560, 380, "entra-id-official", "Entra Kerberos", "File ticket"),
        (760, 380, "files", "Azure Files", "FSLogix profile"),
    ]
    for i, (x, y, icon, title, body) in enumerate(cards, 1):
        s.card(x, y, 165, 100, icon, title, body, number=i, title_size=12.5)
    s.arrow([(110, 305), (135, 305), (135, 170), (160, 170)])
    s.arrow([(325, 170), (360, 170)])
    s.arrow([(525, 170), (560, 170)])
    s.arrow([(725, 170), (760, 170)])
    s.arrow([(842, 220), (842, 300), (642, 300), (642, 380)])
    s.arrow([(725, 430), (760, 430)])
    return s


def profiles_flow(mode: str) -> Svg:
    s = Svg(W, 640, mode, "FSLogix on Azure Files profile flow", "At sign-in, an Entra joined session host retrieves a Kerberos ticket, opens the Azure Files SMB share, and attaches the FSLogix profile container. Storage is sharded across accounts and shares.")
    p = s.p
    s.panel(55, 80, 390, 450, "Session sign-in", "panel_sub")
    s.card(85, 130, 150, 105, "users", "User sign-in", "Start session", number=1)
    s.card(265, 130, 150, 105, "vm", "Session host", "Gets ticket", number=2)
    s.card(175, 320, 180, 105, "disks", "FSLogix container", "Profile attaches", number=5)
    s.panel(520, 80, 390, 450, "Profile storage", "panel_sub")
    s.card(545, 130, 165, 105, "entra-id-official", "Kerberos", "SMB", number=3)
    s.card(725, 130, 165, 105, "files", "Azure Files", "SMB share", number=4)
    s.card(550, 320, 330, 105, "storage-account", "Shard by IOPS and throughput", "Use multiple accounts and shares", number=6)
    s.arrow([(235, 182), (265, 182)])
    s.arrow([(415, 182), (545, 182)])
    s.arrow([(710, 182), (725, 182)])
    s.arrow([(805, 235), (805, 320)])
    s.arrow([(805, 235), (805, 280), (500, 280), (500, 372), (355, 372)])
    s.arrow([(355, 372), (550, 372)], dashed=True)
    return s


def app_attach_flow(mode: str) -> Svg:
    s = Svg(W, 600, mode, "App Attach end to end", "Existing App-V packages take a fast lane straight to the file share. Everything else is converted to MSIX, signed and turned into a CimFS disk image. The share feeds App Attach, which assigns the application to a host pool and a user group and attaches it when the user signs in.")
    s.panel(30, 60, 430, 460, "Step 1: Package, once per application")
    s.card(48, 100, 394, 84, "images", "Fast lane: an existing App-V package", "Use the .appv file as it is. No repackaging, no signing and no disk image.", kind="card_alt")
    s.text(48, 211, "MSIX lane, for everything else", size=11.5, weight=600, colour=str(s.p["muted"]))
    s.card(48, 222, 394, 76, "vm", "Convert the installer to MSIX", "MSIX Packaging Tool, on a clean virtual machine")
    s.card(48, 322, 394, 76, "key-vault", "Sign it with your certificate", "One code signing certificate signs every package")
    s.card(48, 422, 394, 76, "disks", "Create a CimFS disk image", "MSIXMGR expands the MSIX into the image")
    s.arrow([(245, 298), (245, 322)])
    s.arrow([(245, 398), (245, 422)])
    s.panel(490, 60, 200, 460, "Step 2: Store")
    s.card(506, 230, 168, 120, "files", "Azure Files share", "Same Azure region as the session hosts")
    s.panel(720, 60, 250, 460, "Step 3: Deliver")
    s.card(736, 130, 218, 96, "host-pools", "Add and assign", "To a host pool and a user group")
    s.card(736, 300, 218, 120, "users-official", "User signs in", "The app is attached to the session and registers when first opened")
    s.arrow([(442, 142), (475, 142), (475, 270), (506, 270)])
    s.arrow([(442, 460), (590, 460), (590, 350)])
    s.arrow([(674, 290), (705, 290), (705, 178), (736, 178)])
    s.arrow([(845, 226), (845, 300)])
    return s


def app_attach_signing(mode: str) -> Svg:
    s = Svg(W, 520, mode, "Sign once, trust everywhere", "One code signing certificate signs every MSIX package, with a timestamp. One Intune trusted certificate profile pushes the root and intermediate certificates to AVD session hosts and Windows 365 Cloud PCs. A public CA certificate needs no profile, and App-V packages need no certificate.")
    s.panel(30, 60, 280, 270, "1. Get a certificate, once")
    s.card(48, 100, 244, 100, "key-vault", "Code signing certificate", "From your internal CA, or bought from a public CA")
    s.card(48, 226, 244, 86, "images", "Sign every package", "Add a timestamp, so it outlasts the certificate")
    s.arrow([(170, 200), (170, 226)])
    s.panel(340, 60, 290, 270, "2. Trust it, once")
    s.card(356, 100, 258, 112, "intune", "Intune trusted certificate profile", "Pushes your root and intermediate certificates to devices")
    s.card(356, 226, 258, 86, None, "Bought from a public CA?", "Windows already trusts it. Skip this step.", kind="card_alt")
    s.panel(660, 60, 310, 270, "3. Every device trusts every package")
    s.card(676, 100, 278, 84, "host-pools", "AVD session hosts", "Microsoft Entra joined")
    s.card(676, 210, 278, 84, "vm", "Windows 365 Cloud PCs", "Same profile, same packages")
    s.arrow([(292, 150), (356, 150)])
    s.arrow([(614, 142), (676, 142)])
    s.arrow([(614, 185), (645, 185), (645, 252), (676, 252)])
    s.card(30, 356, 940, 76, "images", "App-V packages skip all of this", "Learn's App Attach certificate requirement covers MSIX and Appx packages, so .appv files go straight to the share", kind="card_alt")
    return s


def app_attach_two_platforms(mode: str) -> Svg:
    s = Svg(W, 500, mode, "One package, two platforms", "A signed MSIX package is built once. Azure Virtual Desktop uses it as a CimFS image on Azure Files, attached by App Attach to pooled multi-session hosts. Windows 365 installs the same MSIX through Intune as a line-of-business app on single-session Cloud PCs. App-V packages are an Azure Virtual Desktop bridge only.")
    s.panel(30, 60, 250, 370, "Package once")
    s.card(46, 180, 218, 110, "images", "Signed MSIX package", "Built once by your packaging team")
    s.panel(310, 60, 660, 170, "Azure Virtual Desktop: attach at sign-in")
    s.card(326, 110, 196, 100, "files", "Azure Files share", "CimFS image, made by MSIXMGR")
    s.card(542, 110, 196, 100, "avd", "App Attach", "Assigned to a host pool and group")
    s.card(758, 110, 196, 100, "host-pools", "Pooled hosts", "Windows 11 Enterprise multi-session")
    s.panel(310, 260, 660, 170, "Windows 365: install through Intune")
    s.card(326, 310, 196, 100, "intune", "Intune app", "Line-of-business app, same MSIX")
    s.card(542, 310, 196, 100, "vm", "Cloud PC", "Windows 11 Enterprise, single session")
    s.card(758, 310, 196, 100, None, "App-V packages?", "AVD only. Plan MSIX or Win32 apps for Windows 365", kind="card_alt")
    s.arrow([(264, 200), (295, 200), (295, 160), (326, 160)])
    s.arrow([(264, 270), (295, 270), (295, 360), (326, 360)])
    s.arrow([(522, 160), (542, 160)])
    s.arrow([(738, 160), (758, 160)])
    s.arrow([(522, 360), (542, 360)])
    return s


def images_pipeline(mode: str) -> Svg:
    s = Svg(W, 640, mode, "Image build and session host update pipeline", "A fresh Marketplace image is customised with Azure Image Builder, published to Azure Compute Gallery, referenced by the session host configuration, then rolled through session host update in rings.")
    p = s.p
    stages = [
        (70, 135, "marketplace", "Source", "Image", 1),
        (260, 135, "image-builder", "Image Builder", "Lean base image", 2),
        (450, 135, "compute-gallery", "Compute Gallery", "Versioned images", 3),
        (640, 135, "host-pools", "Host config", "Image and settings", 4),
        (790, 365, "vm", "Ringed update", "Batch replace", 5),
    ]
    for x, y, icon, title, body, n in stages:
        s.card(x, y, 155, 140 if n == 4 else 120, icon, title, body, number=n, fixed=(n == 4), title_size=12.2)
    s.card(220, 365, 150, 92, "host-pools", "Ring 0", "Pilot pool")
    s.card(420, 365, 150, 92, "host-pools", "Ring 1", "Early adopters")
    s.card(620, 365, 150, 92, "host-pools", "Production", "Broad rollout")
    for x in [225, 415, 605]:
        s.arrow([(x, 195), (x + 35, 195)])
    s.arrow([(718, 275), (718, 365)])
    s.arrow([(370, 410), (420, 410)])
    s.arrow([(570, 410), (620, 410)])
    s.arrow([(770, 410), (790, 410)])
    return s


def scaling_lifecycle(mode: str) -> Svg:
    s = Svg(W, 640, mode, "Dynamic autoscaling create and delete lifecycle", "Dynamic autoscaling uses the session host configuration to create hosts for demand and delete disposable ephemeral OS disk hosts as demand falls.")
    p = s.p
    s.card(70, 120, 150, 105, "avd", "Scaling plan", "Schedule", number=1)
    s.card(270, 120, 150, 105, "host-pools", "Host config", "Source", number=2, fixed=True)
    s.card(470, 120, 150, 105, "vm", "Create hosts", "Ramp up", number=3)
    s.card(670, 120, 150, 105, "users", "Users", "Capacity", number=4)
    s.card(470, 360, 150, 105, "vm", "Delete hosts", "Delete only", number=5)
    s.card(270, 360, 150, 105, "monitor", "Logs", "Data", number=6)
    s.arrow([(220, 172), (270, 172)])
    s.arrow([(420, 172), (470, 172)])
    s.arrow([(620, 172), (670, 172)])
    s.arrow([(745, 225), (745, 412), (620, 412)])
    s.arrow([(470, 412), (420, 412)])
    s.arrow([(345, 360), (345, 225)], dashed=True)
    s.label(685, 500, "For ephemeral OS disks, design around create and delete. Do not rely on deallocation.", 230, size=12)
    return s


def monitoring_flow(mode: str) -> Svg:
    s = Svg(W, 640, mode, "Monitoring data flow", "Azure Virtual Desktop diagnostic settings and Azure Monitor Agent data collection rules send control plane and session host telemetry to Log Analytics, then AVD Insights and alerts use the data.")
    p = s.p
    s.card(70, 130, 165, 110, "avd", "AVD resources", "Control plane", number=1)
    s.card(285, 130, 165, 110, "monitor-official", "Diag", "Conn", number=2)
    s.card(70, 360, 165, 110, "vm", "Session hosts", "Guest OS data", number=3)
    s.card(285, 360, 165, 110, "monitor", "Monitor Agent", "DCR collection", number=4)
    s.card(540, 245, 165, 110, "log-analytics", "Log Analytics", "Query store", number=5)
    s.card(765, 160, 165, 95, "dashboard", "AVD Insights", "Workbook", number=6)
    s.card(765, 355, 165, 95, "alerts", "Alerts", "User impact", number=7)
    s.arrow([(235, 185), (285, 185)])
    s.arrow([(450, 185), (500, 185), (500, 300), (540, 300)])
    s.arrow([(235, 415), (285, 415)])
    s.arrow([(450, 415), (500, 415), (500, 300), (540, 300)])
    s.arrow([(705, 300), (735, 300), (735, 207), (765, 207)])
    s.arrow([(705, 300), (735, 300), (735, 402), (765, 402)])
    return s


def security_layers(mode: str) -> Svg:
    s = Svg(W, 660, mode, "Azure Virtual Desktop defence layers", "Security is layered across identity, access, session controls, host integrity, storage, networking, monitoring and administration.")
    p = s.p
    layers = [
        (70, 95, "entra-id", "Identity entry control", "Conditional Access, MFA and SSO"),
        (300, 95, "avd", "Session controls", "Screen, watermark, clipboard"),
        (530, 95, "defender", "Host protection", "Trusted Launch and Defender"),
        (760, 95, "files", "Storage access", "Private endpoints and SMB"),
        (185, 350, "azure-firewall", "Network boundary", "Reverse connect and outbound"),
        (415, 350, "monitor", "Operations evidence", "Diagnostics and alerts"),
        (645, 350, "groups", "Admin access", "RBAC"),
    ]
    for i, (x, y, icon, title, body) in enumerate(layers, 1):
        s.card(x, y, 185, 132, icon, title, body, number=i, title_size=11.5)
    s.arrow([(162, 227), (162, 290), (277, 290), (277, 350)], dashed=True)
    s.arrow([(392, 227), (392, 290), (507, 290), (507, 350)], dashed=True)
    s.arrow([(622, 227), (622, 290), (737, 290), (737, 350)], dashed=True)
    s.label(370, 560, "Defence in depth: no single control is the security boundary.", 260, size=12)
    return s


def identity_two_directories(mode: str) -> Svg:
    s = Svg(W, 640, mode, "Two directories in hybrid identity", "Active Directory Domain Services handles on-premises Windows identity, while Microsoft Entra ID handles cloud identity and token-based cloud application sign-in. Connect Sync or Cloud Sync synchronises users and groups between them.")
    p = s.p
    left = s.panel(45, 60, 360, 500, "On-premises: Active Directory Domain Services", "panel_sub")
    right = s.panel(595, 60, 360, 500, "Cloud: Microsoft Entra ID", "panel_ms")
    c1 = s.card(75, 115, 150, 112, "domain-services", "DCs", "Kerberos, NTLM, LDAP.", number=1, parent=left, body_size=11)
    c2 = s.card(235, 115, 150, 112, "policy", "Group Policy", "Computer and user policy", parent=left, body_size=11)
    c3 = s.card(75, 280, 150, 100, "vm", "Computer accounts", "Domain-joined devices", parent=left)
    c4 = s.card(235, 280, 150, 100, "application-group", "Windows apps", "Windows auth", parent=left)
    e1 = s.card(625, 115, 150, 112, "entra-id", "Entra ID", "OIDC, OAuth, SAML", number=3, parent=right, body_size=11)
    e2 = s.card(785, 115, 150, 100, "policy", "Conditional Access", "Sign-in policy", parent=right)
    e3 = s.card(625, 280, 150, 100, "groups", "Device objects", "Joined or registered", parent=right)
    e4 = s.card(785, 280, 150, 100, "intune", "Microsoft Intune", "Device management", parent=right)
    e5 = s.card(705, 430, 150, 100, "application-group", "Cloud apps", "Microsoft 365 and SaaS", parent=right)
    sync = s.card(425, 250, 150, 120, "entra-id-official", "Sync", "Connect Sync or Cloud Sync", number=2, title_size=12)
    s.arrow([(150, 380), (150, 405), (500, 405), (500, 370)], source=c3, target=sync, label="2")
    s.arrow([(575, 330), (625, 330)], source=sync, target=e3, label="3")
    s.arrow([(150, 227), (150, 250), (310, 250), (310, 280)], source=c1, target=c4, label="1")
    return s


def identity_join_models(mode: str) -> Svg:
    s = Svg(W, 640, mode, "Device join models and directory objects", "Four Microsoft identity join models showing whether the device has an object in Active Directory, Microsoft Entra ID or both.")
    p = s.p
    ad = s.panel(45, 65, 910, 150, "Active Directory", "panel_sub")
    entra = s.panel(45, 485, 910, 150, "Microsoft Entra ID", "panel_ms")
    ad_obj = s.card(400, 95, 200, 100, "domain-services", "AD computer accounts", "Kerberos TGT and Group Policy", parent=ad, title_size=12)
    entra_obj = s.card(395, 515, 210, 100, "entra-id", "Entra device objects", "PRT and cloud SSO", parent=entra, title_size=12)
    models = [
        (60, "Entra registered", "BYOD. Entra object. Not a session host.", "users", False, True),
        (285, "Entra joined", "Entra object only. PRT. Intune. North Star hosts.", "vm", False, True),
        (510, "Hybrid joined", "AD and Entra. TGT and PRT.", "vm", True, True),
        (735, "AD DS joined", "AD computer only. TGT. Group Policy.", "domain-services", True, False),
    ]
    for i, (x, title, body, icon, to_ad, to_entra) in enumerate(models, 1):
        card = s.card(x, 260, 185, 120, icon, title, body, number=i, title_size=12.2)
        if to_ad:
            s.arrow([(x + 92, 260), (x + 92, 205), (500, 205), (500, 195)], source=card, target=ad_obj, label=f"{i}-ad")
        if to_entra:
            s.arrow([(x + 92, 380), (x + 92, 470), (500, 470), (500, 515)], source=card, target=entra_obj, label=f"{i}-entra")
    return s


def identity_tokens_on_device(mode: str) -> Svg:
    # One row per credential: the issuer on the left, the credential on the session host in the middle,
    # and what uses it on the right. Every arrow is straight, so no two lines share a path.
    s = Svg(W, 720, mode, "Credentials on a signed-in session host", "A Microsoft Entra joined session host holds a Primary Refresh Token and a partial TGT from Microsoft Entra ID, access tokens for cloud apps, a Microsoft Entra Kerberos ticket for Azure Files, and a full TGT from a domain controller for on-premises resources.")
    centre = s.panel(320, 60, 360, 615, "Microsoft Entra joined session host", "panel_sub")
    entra = s.card(40, 110, 230, 110, "entra-id", "Microsoft Entra ID", "Issues the PRT and a partial TGT")
    prt = s.card(350, 110, 300, 110, "entra-id", "Primary Refresh Token", "Plus a partial TGT for AD DS", parent=centre)
    access = s.card(350, 255, 300, 110, "application-group", "Access tokens", "One per app, from the PRT", parent=centre)
    m365 = s.card(730, 255, 230, 110, "application-group", "Microsoft 365", "Cloud apps accept the tokens")
    ticket = s.card(350, 400, 300, 110, "files", "Azure Files ticket", "From Microsoft Entra Kerberos", parent=centre)
    files = s.card(730, 400, 230, 110, "files", "Azure Files", "FSLogix profile share")
    dc = s.card(40, 545, 230, 110, "domain-services", "Domain controller", "Trades the partial TGT for a full TGT")
    tgt = s.card(350, 545, 300, 110, "domain-services", "Full TGT", "Gets service tickets from the domain controller", parent=centre)
    app = s.card(730, 545, 230, 110, "storage-account", "On-premises app", "Accepts the service ticket")
    s.arrow([(270, 165), (350, 165)], source=entra, target=prt, label="1")
    s.arrow([(500, 220), (500, 255)], source=prt, target=access, label="2")
    s.arrow([(650, 310), (730, 310)], source=access, target=m365, label="2-use")
    s.arrow([(155, 220), (155, 455), (350, 455)], source=entra, target=ticket, label="3")
    s.arrow([(650, 455), (730, 455)], source=ticket, target=files, label="3-use")
    s.arrow([(270, 600), (350, 600)], source=dc, target=tgt, label="4")
    s.arrow([(650, 600), (730, 600)], source=tgt, target=app, label="5")
    s.badge(295, 165, "1")
    s.badge(500, 237.5, "2")
    s.badge(155, 335, "3")
    s.badge(295, 600, "4")
    s.badge(705, 600, "5")
    return s


def identity_onprem_access(mode: str) -> Svg:
    # The session host is the actor: it collects the partial TGT, trades it at a domain controller and presents
    # the service ticket. Machine authentication is a separate, blocked path.
    s = Svg(W, 700, mode, "On-premises access from an Entra joined session host", "A Microsoft Entra joined session host gets a partial TGT from Microsoft Entra ID, trades it at a domain controller for a full TGT and service tickets, and reaches on-premises apps as the user. Machine authentication isn't supported because the host has no AD computer account.")
    p = s.p
    host = s.card(40, 110, 250, 440, "vm", "Entra joined session host", "User signed in with single sign-on. No AD computer account.")
    entra = s.card(380, 110, 280, 100, "entra-id", "Microsoft Entra ID", "Issues a partial TGT with the PRT")
    dc = s.card(380, 250, 280, 100, "domain-services", "Domain controller", "Trades it for a full TGT and issues service tickets")
    app = s.card(380, 390, 280, 100, "storage-account", "File share or app", "Works as the user, with Kerberos")
    blocked = s.card(380, 560, 280, 100, "domain-services", "Machine authentication", "Not supported: no AD computer account", kind="card_alt")
    hybrid = s.card(740, 560, 220, 100, "host-pools", "Hybrid joined pool", "For apps that need it", kind="card_alt")
    s.label(740, 255, "Needs a Kerberos server object and line of sight to a domain controller.", 220, size=12)
    s.arrow([(290, 160), (380, 160)], source=host, target=entra, label="1")
    s.arrow([(290, 300), (380, 300)], source=host, target=dc, label="2")
    s.arrow([(290, 440), (380, 440)], source=host, target=app, label="3")
    s.arrow([(165, 550), (165, 610), (380, 610)], dashed=True, colour=p["danger"], source=host, target=blocked, label="blocked")
    s.arrow([(660, 610), (740, 610)], dashed=True, colour=p["danger"], source=blocked, target=hybrid, label="blocked")
    s.badge(335, 160, "1")
    s.badge(335, 300, "2")
    s.badge(335, 440, "3")
    return s


DIAGRAMS = [
    ("north-star-architecture", north_star, "docs/index.md and docs/overview/how-it-fits-together.md", "The big picture", "The North Star pooled Azure Virtual Desktop architecture with users, Microsoft-managed services, session hosts, storage, images, Intune and monitoring.", ["Sign in", "Connect", "Reverse connect", "Profiles and applications", "Session host lifecycle", "Image", "Policy", "Observe"], [LEARN["host_pool_management"], LEARN["rdp_shortpath"], LEARN["security"], LEARN["fslogix_store"], LEARN["app_attach"], LEARN["insights"]]),
    ("two-host-pools", two_host_pools, "docs/getting-there/stepping-stones.md", "Hybrid joined pool for legacy applications", "A North Star pool and a separate hybrid joined pool published from one workspace, with AD DS, synchronisation and separate storage and image paths.", ["North Star pooled pool", "Legacy pooled pool", "One workspace publishes both"], [LEARN["entra_hosts"], LEARN["device_join"], LEARN["host_pool_management"]]),
    ("personal-desktops", personal_desktops, "docs/getting-there/stepping-stones.md", "Personal host pool or Windows 365", "Dedicated desktop options: a personal host pool with standard management or Windows 365 Cloud PCs as an alternative to pooled desktops.", ["Personal host pool", "Windows 365 Cloud PC", "Review and move back to pooled where possible"], [LEARN["host_pool_management"], "https://learn.microsoft.com/windows-365/enterprise/overview"]),
    ("remoteapp", remoteapp, "docs/app-attach/index.md", "RemoteApp and desktop application groups", "A pooled host pool publishing both a desktop application group and a RemoteApp application group, with applications delivered through App Attach.", ["Desktop application group", "RemoteApp application group", "App assignment", "Package mount"], [LEARN["app_attach"], LEARN["app_attach_setup"]]),
    ("multi-region-resilience", multi_region, "docs/bcdr/index.md", "Regional recovery pattern", "An active-passive regional resilience pattern that protects profiles, packages, images and infrastructure as code, while rebuilding disposable session hosts.", ["Protect profile and package state", "Replicate image versions", "Rebuild from infrastructure as code"], [LEARN["regional"], LEARN["backup"], LEARN["compute_gallery"], LEARN["ephemeral"]]),
    ("private-connectivity", private_connectivity, "docs/networking/index.md", "Private and public connectivity paths", "Client, service and host paths for Private Link, RDP Shortpath over managed networks, and public STUN or TURN paths.", ["Private service access", "Public service path", "Reverse connect", "RDP Shortpath path", "Storage private endpoint"], [LEARN["private_link"], LEARN["rdp_shortpath"], LEARN["network"]]),
    ("dependency-map", dependency_map, "docs/overview/dependency-map.md", "Master dependency map", "A numbered dependency map showing what must exist first, what is fixed at host pool creation and which relationships are requirements or recommendations.", None, [LEARN["licensing"], LEARN["quotas"], LEARN["host_pool_management"], LEARN["autoscale"], LEARN["session_host_update"], LEARN["ephemeral"], LEARN["entra_hosts"], LEARN["device_join"], LEARN["sso"], LEARN["kerberos_files"], LEARN["intune"], LEARN["managed_identity"], LEARN["app_attach"], LEARN["service_principal"]], DEPENDENCY_NODES),
    ("identity-flow", identity_flow, "docs/identity/index.md", "How it fits", "Identity flow for sign-in, Conditional Access, single sign-on and Microsoft Entra Kerberos access to Azure Files.", ["Authenticate", "Evaluate Conditional Access", "Get feed and broker session", "Sign in with SSO", "Retrieve Kerberos ticket", "Open profile share"], [LEARN["sso"], LEARN["mfa"], LEARN["kerberos_files"], LEARN["entra_hosts"]]),
    ("profiles-fslogix", profiles_flow, "docs/profiles/index.md", "How it fits", "FSLogix profile flow from user sign-in through Microsoft Entra Kerberos to Azure Files, with sharding across storage accounts and shares.", ["User signs in", "Host retrieves Kerberos ticket", "Kerberos authenticates SMB", "Open Azure Files", "Attach profile container", "Shard by IOPS and throughput"], [LEARN["fslogix_store"], LEARN["files_identity"], LEARN["kerberos_files"], LEARN["files_scale"]]),
    ("app-attach-flow", app_attach_flow, "docs/app-attach/index.md", "The whole process on one page", "App Attach end to end. Step 1, package once per application: an existing App-V package takes the fast lane as it is, and everything else is converted to MSIX with the MSIX Packaging Tool, signed with one code signing certificate, and turned into a CimFS disk image with MSIXMGR. Step 2, store it on an Azure Files share in the same region as the session hosts. Step 3, deliver: add it and assign it to a host pool and a user group, and it's attached when the user signs in.", ["Fast lane: use an existing App-V package as it is", "Convert the installer to MSIX with the MSIX Packaging Tool", "Sign it with your code signing certificate", "Create a CimFS disk image with MSIXMGR", "Store it on an Azure Files share", "Add it and assign it to a host pool and a user group", "The user signs in and the app is attached"], [LEARN["app_attach"], LEARN["app_attach_image"], LEARN["msix_tool"], LEARN["app_attach_setup"]]),
    ("app-attach-signing", app_attach_signing, "docs/app-attach/certificates.md", "Sign once, trust everywhere", "Sign once, trust everywhere. Get one code signing certificate from your internal CA or a public CA and sign every MSIX package with it, adding a timestamp. One Intune trusted certificate profile pushes the root and intermediate certificates to AVD session hosts and Windows 365 Cloud PCs; a public CA certificate is already trusted, so it needs no profile. App-V packages need no certificate.", ["Get one code signing certificate", "Sign and timestamp every MSIX package", "Push trust once with an Intune trusted certificate profile", "Every AVD session host and Cloud PC trusts every package"], [LEARN["app_attach"], LEARN["msix_sign"], LEARN["msix_intune"]]),
    ("app-attach-two-platforms", app_attach_two_platforms, "docs/app-attach/avd-and-windows-365.md", "One package, two platforms", "One package, two platforms. A signed MSIX package is built once. Azure Virtual Desktop turns it into a CimFS image on an Azure Files share, and App Attach attaches it to pooled Windows 11 Enterprise multi-session hosts. Windows 365 installs the same MSIX through Intune as a line-of-business app on single-session Cloud PCs. App-V packages are an Azure Virtual Desktop bridge only, so plan MSIX or Win32 apps for Windows 365.", ["Build and sign the MSIX once", "AVD: CimFS image on Azure Files, attached by App Attach", "Windows 365: the same MSIX installed through Intune"], [LEARN["app_attach"], LEARN["msix_intune"], LEARN["w365_apps"], LEARN["w365_images"]]),
    ("images-pipeline", images_pipeline, "docs/images/index.md", "How it fits", "Image pipeline from Marketplace source through Azure Image Builder and Azure Compute Gallery to session host configuration and session host update rings.", ["Marketplace source", "Build image", "Publish version", "Reference in session host configuration", "Update in rings"], [LEARN["image_builder"], LEARN["compute_gallery"], LEARN["session_host_update"], LEARN["host_pool_management"]]),
    ("scaling-lifecycle", scaling_lifecycle, "docs/scaling/index.md", "How it fits", "Dynamic autoscaling lifecycle for ephemeral OS disk pooled hosts, showing create, use, drain and delete.", ["Scaling plan", "Read session host configuration", "Create hosts", "Serve users", "Drain and delete", "Observe diagnostics"], [LEARN["autoscale"], LEARN["ephemeral"], LEARN["host_pool_management"]]),
    ("monitoring-flow", monitoring_flow, "docs/monitoring/index.md", "How it fits", "Monitoring data flow from AVD diagnostic settings and Azure Monitor Agent to Log Analytics, AVD Insights and alerts.", ["AVD diagnostics source", "Diagnostic settings", "Session hosts", "Azure Monitor Agent and DCR", "Log Analytics", "AVD Insights", "Alerts"], [LEARN["diagnostics"], LEARN["insights"], LEARN["ama"]]),
    ("security-layers", security_layers, "docs/security/index.md", "Control map", "Defence-in-depth layers for identity, session controls, host protection, storage, networking, monitoring and administration.", None, [LEARN["security"], LEARN["mfa"], LEARN["private_link"], LEARN["managed_identity"]]),
    ("identity-two-directories", identity_two_directories, "docs/demystified/two-directories.md", "Identity demystified", "Active Directory Domain Services and Microsoft Entra ID shown as two directories, with users and groups synchronised by Microsoft Entra Connect Sync or Cloud Sync.", ["Sign in on-premises with Kerberos or NTLM", "Synchronise users and groups", "Sign in to the cloud with tokens"], [LEARN["hybrid_identity"], LEARN["entra_what_is"], LEARN["cloud_sync"], LEARN["ad_ds"], LEARN["identity_platform"]]),
    ("identity-join-models", identity_join_models, "docs/demystified/device-join-models.md", "Identity demystified", "Four device join models showing whether the device has an object in Active Directory, Microsoft Entra ID or both.", ["Registered device has an Entra object", "Entra joined device has an Entra object and PRT", "Hybrid joined device has AD and Entra objects", "AD DS joined device has an AD computer account"], [LEARN["device_overview"], LEARN["device_registered"], LEARN["concept_join"], LEARN["hybrid_join"], LEARN["prt"]]),
    ("identity-tokens-on-a-device", identity_tokens_on_device, "docs/demystified/tokens-and-tickets.md", "Identity demystified", "Credentials on a signed-in Microsoft Entra joined session host: a Primary Refresh Token and a partial TGT from Microsoft Entra ID, access tokens for Microsoft 365, a Microsoft Entra Kerberos ticket for the Azure Files profile share, and a full TGT from a domain controller that gets service tickets for on-premises apps.", ["Microsoft Entra ID issues the Primary Refresh Token and, with a Kerberos server object, a partial TGT", "The PRT gets access tokens that cloud apps such as Microsoft 365 accept", "Microsoft Entra Kerberos issues the ticket for the Azure Files profile share", "A domain controller trades the partial TGT for a full TGT", "The full TGT gets service tickets for on-premises apps"], [LEARN["sso"], LEARN["prt"], LEARN["device_sso_onprem"], LEARN["kerberos_files"], LEARN["cloud_kerberos_trust"], LEARN["passwordless_onprem"]]),
    ("identity-onprem-access", identity_onprem_access, "docs/demystified/application-authentication.md", "Identity demystified", "On-premises access from a Microsoft Entra joined session host: Microsoft Entra ID issues a partial TGT, a domain controller trades it for a full TGT and issues service tickets, and the user reaches file shares and apps with Kerberos. Machine authentication isn't supported because the host has no AD computer account, so those apps use a hybrid joined pool.", ["The session host gets a partial TGT from Microsoft Entra ID, with the PRT", "The session host trades the partial TGT at a domain controller for a full TGT, then gets service tickets", "The session host presents the service ticket and reaches the file share or app as the user"], [LEARN["sso"], LEARN["device_sso_onprem"], LEARN["kerberos_files"], LEARN["cloud_kerberos_trust"], LEARN["passwordless_onprem"], "https://learn.microsoft.com/entra/identity/devices/device-join-plan#understand-considerations-for-applications-and-resources"]),
]


def write_manifest() -> None:
    lines: list[str] = [
        "# Diagram manifest",
        "",
        "Generated by `python scripts/diagrams/build_all.py`.",
        "",
        "All diagrams are generic and use Contoso only where an organisation name would otherwise be needed. All file names have a light and dark variant.",
        "",
    ]
    for item in manifest:
        name = item["name"]
        lines.extend(
            [
                f"## {name}",
                "",
                f"- Files: `docs/assets/images/{name}-light.svg`, `docs/assets/images/{name}-dark.svg`",
                f"- Intended page: {item['page']}",
                f"- Intended section: {item['section']}",
                f"- Alt text: {item['alt']}",
            ]
        )
        steps = item["steps"]
        if steps:
            lines.append("- Numbered-step text:")
            for i, step in enumerate(steps, 1):
                lines.append(f"  {i}. {step}")
        nodes = item["nodes"]
        if nodes:
            lines.append("- Dependency map node table:")
            for num, title, body in nodes:
                lines.append(f"  {num}. **{title}** - {body}")
        lines.append("- Microsoft Learn URLs:")
        for url in item["urls"]:
            lines.append(f"  - {url}")
        lines.append("")
    text = scrub("\n".join(lines))
    (Path(__file__).resolve().parent / "MANIFEST.md").write_text(text, encoding="utf-8", newline="\n")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw, page, section, alt, steps, urls, *rest in DIAGRAMS:
        linted = 0
        for mode in ("light", "dark"):
            svg = draw(mode)
            svg.fit_to_content()
            errors = svg.lint(f"{name}-{mode}")
            if errors:
                raise SystemExit("\n".join(errors))
            path = OUT / f"{name}-{mode}.svg"
            path.write_text(scrub(svg.render()), encoding="utf-8", newline="\n")
            linted += 1
        print(f"lint ok: {name} ({linted} variants)")
        nodes = rest[0] if rest else None
        add_manifest(name, page, section, alt, steps, urls, nodes)
        print(f"wrote {name}-light.svg and {name}-dark.svg")
    write_manifest()
    print("wrote scripts/diagrams/MANIFEST.md")


if __name__ == "__main__":
    main()
