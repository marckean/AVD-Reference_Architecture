---
title: Glossary
description: Plain-English definitions of the terms used across the North Star, each linked to the Microsoft Learn article it comes from.
---

# Glossary

!!! abstract "At a glance"
    - Short definitions of the terms used on this site, in plain English.
    - Each term links to the Microsoft Learn article that defines it.
    - Hover over an abbreviation anywhere on the site to see what it stands for.

## A

App Attach
:   Azure Virtual Desktop feature that attaches applications from packages to user sessions, so applications aren't installed on session hosts or in the image. It replaced MSIX app attach, which was deprecated on 1 June 2025. [App Attach in AVD](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

App-V
:   Microsoft Application Virtualization. App Attach can deliver App-V packages to Azure Virtual Desktop without an App-V server. The App-V client and sequencer are in fixed extended support. [App-V support policy](https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy)

Application group
:   The object that gives users access to a full desktop or to RemoteApp applications from a host pool. [AVD terminology](https://learn.microsoft.com/azure/virtual-desktop/terminology#application-groups)

Appx
:   Windows application package format that App Attach supports. [App Attach in AVD](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

Autoscale
:   The native Azure Virtual Desktop service that scales session hosts according to a scaling plan's schedules and the capacity in use. [Autoscale glossary](https://learn.microsoft.com/azure/virtual-desktop/autoscale-glossary)

AVD Insights
:   Azure Monitor workbook for understanding an Azure Virtual Desktop environment: connections, hosts, sign-in performance and more. [AVD Insights](https://learn.microsoft.com/azure/virtual-desktop/insights)

Azure Artifact Signing
:   Microsoft's managed code signing service, formerly called Trusted Signing. Learn recommends it for production MSIX signing. Its Public Trust certificates are currently available to organisations in the USA, Canada, the European Union and the United Kingdom. [Sign an MSIX package](https://learn.microsoft.com/windows/msix/package/signing-package-overview)

Azure Compute Gallery
:   Azure service for managing, versioning and replicating VM images through image definitions and image versions. [Azure Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/azure-compute-gallery)

Azure Files provisioned v2
:   Azure Files billing model where you provision storage, IOPS and throughput explicitly. [Azure Files billing](https://learn.microsoft.com/azure/storage/files/understanding-billing#provisioned-v2-model)

Azure Image Builder
:   Managed Azure service that builds customised VM images from a template. Also called Azure VM Image Builder. [Azure Image Builder overview](https://learn.microsoft.com/azure/virtual-machines/image-builder-overview)

Azure Monitor Agent
:   The agent that collects guest operating system data from virtual machines for Azure Monitor. [Azure Monitor Agent](https://learn.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-overview)

## B to C

Breadth-first
:   Load-balancing algorithm that spreads new sessions across the available session hosts. [Configure host pool load balancing](https://learn.microsoft.com/azure/virtual-desktop/configure-host-pool-load-balancing)

Capacity threshold
:   The percentage of used host pool capacity that triggers a scaling action. [Create and assign a scaling plan](https://learn.microsoft.com/azure/virtual-desktop/autoscale-create-assign-scaling-plan)

CimFS
:   Composite Image File System. The disk image type Learn recommends for App Attach, because it mounts and unmounts faster than VHD or VHDX. [App Attach in AVD](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

Cloud Cache
:   FSLogix capability that writes profile containers to more than one storage location for resilience. [FSLogix business continuity](https://learn.microsoft.com/fslogix/concepts-container-recovery-business-continuity)

Code signing certificate
:   A certificate with object identifier 1.3.6.1.5.5.7.3.3, used to sign MSIX and Appx packages. The whole certificate chain must be trusted on the device that runs the package. [App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

Conditional Access
:   Microsoft Entra policies applied at sign-in, such as requiring MFA. With single sign-on, target both **Azure Virtual Desktop** and **Windows Cloud Login**. [Enforce MFA with Conditional Access](https://learn.microsoft.com/azure/virtual-desktop/set-up-mfa)

Context-based redirections
:   Preview feature that turns clipboard, drive, printer and USB redirection on or off for a session, based on a Conditional Access authentication context. [Context-based redirections](https://learn.microsoft.com/azure/virtual-desktop/context-based-redirections-avd)

Custom image template
:   Azure Virtual Desktop feature, built on Azure Image Builder, that defines a source image, customisations and where the built image goes. [Custom image templates](https://learn.microsoft.com/azure/virtual-desktop/custom-image-templates)

## D to E

Data collection rule
:   Azure Monitor object that defines what data is collected and where it's sent. [Data collection rules](https://learn.microsoft.com/azure/azure-monitor/data-collection/data-collection-rule-overview)

Depth-first
:   Load-balancing algorithm that fills one session host to its maximum session limit before using the next. [Configure host pool load balancing](https://learn.microsoft.com/azure/virtual-desktop/configure-host-pool-load-balancing)

Desktop Virtualization User
:   Built-in role that lets users use the desktop or applications in an application group. [Built-in roles for AVD](https://learn.microsoft.com/azure/virtual-desktop/rbac#desktop-virtualization-user)

dsregcmd
:   Windows command whose **/status** option shows a device's join state and the state of its Primary Refresh Token and Kerberos tickets. [Troubleshoot devices by using dsregcmd](https://learn.microsoft.com/entra/identity/devices/troubleshoot-device-dsregcmd)

Dynamic autoscaling
:   Scaling method that powers session hosts on and off and also creates and deletes them. It can only be used for pooled host pools with a session host configuration. [Autoscale glossary](https://learn.microsoft.com/azure/virtual-desktop/autoscale-glossary)

Ephemeral OS disk
:   An OS disk created on the VM's local storage instead of in Azure Storage. Session hosts with ephemeral OS disks can't be started and deallocated, so they're created and deleted instead. [Ephemeral OS disks on AVD](https://learn.microsoft.com/azure/virtual-desktop/deploy/session-hosts/ephemeral-os-disks)

Exclusion tag
:   A tag that stops autoscale acting on the session hosts that carry it. [Create and assign a scaling plan](https://learn.microsoft.com/azure/virtual-desktop/autoscale-create-assign-scaling-plan)

## F to H

FSLogix profile container
:   A VHD or VHDX file on a file share that holds the user profile. It's attached at sign-in, so the profile appears local on any session host. [Store FSLogix profile containers](https://learn.microsoft.com/azure/virtual-desktop/store-fslogix-profile)

Golden image
:   A prepared source image used to create session hosts. [Create a golden image](https://learn.microsoft.com/azure/virtual-desktop/set-up-golden-image)

Group managed service account (gMSA)
:   A domain account for running services. Windows manages its password automatically, and several servers can use it. [Group managed service accounts](https://learn.microsoft.com/windows-server/security/group-managed-service-accounts/group-managed-service-accounts-overview)

Host pool
:   A collection of Azure virtual machines registered to Azure Virtual Desktop as session hosts. Pooled host pools share hosts between users. Personal host pools give each user their own. [AVD terminology](https://learn.microsoft.com/azure/virtual-desktop/terminology#host-pools)

## I to L

Image definition and image version
:   Azure Compute Gallery objects. A definition describes an image family, and a version is a specific build you deploy. [Azure Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/azure-compute-gallery)

Kerberos
:   The default authentication protocol for Windows domains. A user gets a ticket-granting ticket at sign-in, then uses it to get a service ticket for each service. [Kerberos authentication overview](https://learn.microsoft.com/windows-server/security/kerberos/kerberos-authentication-overview)

Kerberos constrained delegation (KCD)
:   Lets a trusted service get Kerberos service tickets on a user's behalf, for specific back-end services only. Microsoft Entra application proxy uses it for on-premises apps that use integrated Windows authentication. [Single sign-on with Kerberos constrained delegation](https://learn.microsoft.com/entra/identity/app-proxy/how-to-configure-sso-with-kcd)

Kerberos server object
:   An object created in Active Directory Domain Services so that Entra joined and hybrid joined session hosts using single sign-on can get Kerberos tickets for on-premises resources. [Create a Kerberos server object](https://learn.microsoft.com/azure/virtual-desktop/configure-single-sign-on#create-a-kerberos-server-object)

Kerberos/CloudKerberosTicketRetrievalEnabled
:   The policy setting that lets session hosts retrieve Microsoft Entra Kerberos tickets for Azure Files. Set it to `1` through the Intune settings catalog. [Enable Microsoft Entra Kerberos for Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable)

Key Distribution Center (KDC)
:   The Kerberos service on each domain controller that issues ticket-granting tickets and service tickets. [Kerberos authentication overview](https://learn.microsoft.com/windows-server/security/kerberos/kerberos-authentication-overview)

LAN Manager authentication level
:   The security policy, stored as the **LmCompatibilityLevel** registry value, that sets which LM, NTLM and NTLMv2 responses a computer sends and a domain controller accepts. [Network security: LAN Manager authentication level](https://learn.microsoft.com/windows/security/threat-protection/security-policy-settings/network-security-lan-manager-authentication-level)

Line-of-business app (Intune)
:   An app you upload to Intune yourself, such as a signed MSIX package. Windows 365 Cloud PCs can receive MSIX packages this way. [Deploy MSIX apps with Microsoft Intune](https://learn.microsoft.com/windows/msix/desktop/managing-your-msix-deployment-intune)

Log on blocking registration
:   App Attach registration mode where assigned applications are fully registered during sign-in. [App Attach in AVD](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

## M

Machine authentication
:   An application or service authenticating with the device's Active Directory computer account rather than as the signed-in user. Microsoft Entra joined devices have no computer account, so on-premises apps that rely on it aren't supported there. [Plan your Microsoft Entra join deployment](https://learn.microsoft.com/entra/identity/devices/device-join-plan#understand-considerations-for-applications-and-resources)

Managed identity (host pool)
:   An identity on the host pool that Azure Virtual Desktop uses for session host configuration, autoscale and Start VM on Connect. [Configure managed identity](https://learn.microsoft.com/azure/virtual-desktop/configure-managed-identity)

Max session limit
:   The maximum number of sessions a session host accepts. Autoscale needs a custom value, not the default. [Configure host pool load balancing](https://learn.microsoft.com/azure/virtual-desktop/configure-host-pool-load-balancing)

Microsoft Entra application proxy
:   Publishes on-premises web apps through Microsoft Entra ID, and can sign users in to apps that use integrated Windows authentication by using Kerberos constrained delegation. [Single sign-on with Kerberos constrained delegation](https://learn.microsoft.com/entra/identity/app-proxy/how-to-configure-sso-with-kcd)

Microsoft Entra Connect Sync and Cloud Sync
:   The tools that synchronise users and groups from Active Directory Domain Services to Microsoft Entra ID, creating hybrid identities. [What is hybrid identity?](https://learn.microsoft.com/entra/identity/hybrid/whatis-hybrid-identity)

Microsoft Entra Domain Services
:   A managed domain in Azure that provides domain join, Group Policy, LDAP and Kerberos or NTLM authentication without running your own domain controllers. App Attach doesn't support it. [What is Microsoft Entra Domain Services?](https://learn.microsoft.com/entra/identity/domain-services/overview), [App Attach identity providers](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview#identity-providers)

Microsoft Entra hybrid joined
:   A device joined to on-premises Active Directory and also registered in Microsoft Entra ID, so it has both an AD computer account and a Microsoft Entra device object. [Microsoft Entra hybrid joined devices](https://learn.microsoft.com/entra/identity/devices/concept-hybrid-join)

Microsoft Entra joined session host
:   A session host joined directly to Microsoft Entra ID instead of Active Directory Domain Services. [Microsoft Entra joined session hosts](https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts)

Microsoft Entra Kerberos
:   Lets Microsoft Entra ID issue Kerberos tickets for SMB access to Azure Files, so Entra joined hosts can reach profile shares. [Azure Files identity-based access](https://learn.microsoft.com/azure/storage/files/storage-files-active-directory-overview)

Microsoft Entra registered
:   A personal or bring-your-own device where a user has added a work account. It has a Microsoft Entra device object but isn't joined to the organisation. [Microsoft Entra registered devices](https://learn.microsoft.com/entra/identity/devices/concept-device-registration)

Minimum percentage of active hosts
:   The percentage of the minimum host pool size that autoscale keeps available in a phase. Learn recommends 100% for host pools with ephemeral OS disks. [Ephemeral OS disks on AVD](https://learn.microsoft.com/azure/virtual-desktop/deploy/session-hosts/ephemeral-os-disks)

MSIX
:   The modern Windows application package format, and the long-term format for App Attach. [App Attach in AVD](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

MSIX Packaging Tool and MSIXMGR tool
:   Microsoft tools for creating MSIX packages, and for turning them into CimFS or VHDX images for App Attach. [Create an MSIX image](https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image)

Multimedia redirection
:   Redirects video playback and calls in the browser to the local device for processing. [Multimedia redirection](https://learn.microsoft.com/azure/virtual-desktop/multimedia-redirection-video-playback-calls)

## N to R

Negotiate
:   The Windows security package that selects Kerberos unless it can't be used, and otherwise falls back to NTLM. [Microsoft Negotiate](https://learn.microsoft.com/windows/win32/secauthn/microsoft-negotiate)

NTLMv1
:   A legacy authentication protocol version, removed from Windows 11 version 24H2 and Windows Server 2025. [Removed features](https://learn.microsoft.com/windows/whats-new/removed-features)

NTLMv2
:   The NTLM version that still works now NTLMv1 is removed, starting in Windows 11 version 24H2 and Windows Server 2025. All NTLM versions are deprecated. [Removed features](https://learn.microsoft.com/windows/whats-new/removed-features), [Deprecated features](https://learn.microsoft.com/windows/whats-new/deprecated-features)

On-demand registration
:   App Attach registration mode where full registration of an application is deferred until it's launched. [App Attach in AVD](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

Open handles (Azure Files)
:   Azure Files limits how many handles can be open at once on a file, a directory and a share's root directory. FSLogix and App Attach both hold handles. [Azure Files scale targets](https://learn.microsoft.com/azure/storage/files/storage-files-scale-targets#file-scale-targets)

Package Support Framework
:   Runtime fixes for applications that need help to run in the MSIX container. [Package Support Framework overview](https://learn.microsoft.com/windows/msix/psf/package-support-framework-overview)

Partial TGT
:   A Kerberos ticket-granting ticket for an on-premises Active Directory domain, issued by Microsoft Entra ID and holding only the user's SID. The device trades it at a domain controller for a full TGT. It needs a Kerberos server object. [Passwordless sign-in to on-premises resources](https://learn.microsoft.com/entra/identity/authentication/howto-authentication-passwordless-security-key-on-premises)

Power management autoscaling
:   Scaling method that powers existing session hosts on and off. Use it with standard management host pools. [Autoscale glossary](https://learn.microsoft.com/azure/virtual-desktop/autoscale-glossary)

Primary Refresh Token (PRT)
:   A token that Microsoft Entra ID issues to a user on a registered, joined or hybrid joined device, used for single sign-on to apps on that device. [What is a Primary Refresh Token?](https://learn.microsoft.com/entra/identity/devices/concept-primary-refresh-token)

Private endpoint
:   A private IP address inside a virtual network for reaching an Azure service, such as Azure Files. [Azure Files network endpoints](https://learn.microsoft.com/azure/storage/files/storage-files-networking-endpoints)

RDP Multipath
:   Monitors several network paths for a session and switches to the most reliable one, reducing disconnections. [RDP Multipath](https://learn.microsoft.com/azure/virtual-desktop/rdp-multipath)

RDP properties
:   Host pool settings that control session behaviour, including single sign-on and device redirection. [Supported RDP properties](https://learn.microsoft.com/azure/virtual-desktop/rdp-properties)

RDP Shortpath
:   A UDP-based transport between the client and the session host, which improves on the default TCP connection. On public networks it uses STUN for direct paths and TURN for relayed ones. [RDP Shortpath](https://learn.microsoft.com/azure/virtual-desktop/rdp-shortpath)

Recovery Services vault
:   The Azure Backup container that holds backup configuration and backup data, including vaulted backups of Azure file shares. [About Azure Files backup](https://learn.microsoft.com/azure/backup/azure-file-share-backup-overview)

Regional host pool
:   A host pool whose metadata is stored in the selected Azure region rather than in a geographical database shared across regions. [Regional host pools](https://learn.microsoft.com/azure/virtual-desktop/regional-host-pools)

Reverse connect
:   The connection model where session hosts and clients connect out to the Azure Virtual Desktop gateway, so session hosts need no inbound ports. [AVD network connectivity](https://learn.microsoft.com/azure/virtual-desktop/network-connectivity#reverse-connect-transport)

## S

Scaling plan
:   The Azure resource that defines scaling schedules and behaviour for one or more host pools. [Autoscale scenarios](https://learn.microsoft.com/azure/virtual-desktop/autoscale-scenarios)

Screen capture protection
:   Stops remote content being captured in screenshots or screen sharing on supported clients. [Screen capture protection](https://learn.microsoft.com/azure/virtual-desktop/screen-capture-protection)

Service principal name (SPN)
:   The name that identifies a service instance to Kerberos, so a client can request a service ticket for it. [Service principal names](https://learn.microsoft.com/windows/win32/ad/service-principal-names)

Service ticket
:   A Kerberos ticket for one service, which a domain controller issues when the client presents its ticket-granting ticket. [Kerberos authentication overview](https://learn.microsoft.com/windows-server/security/kerberos/kerberos-authentication-overview)

Session host
:   A virtual machine that runs users' desktops or applications. [AVD terminology](https://learn.microsoft.com/azure/virtual-desktop/terminology#host-pools)

Session host configuration
:   A host pool sub-resource that defines what every session host looks like: image, size, OS disk, join type, network and more. It's the basis of automated host pools. [Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches#session-host-configuration)

Session host management policy
:   A host pool sub-resource that defines how session hosts are created and updated: time zone, batch size, logoff delay and message, and failure clean-up. [Host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches#session-host-management-policy)

Session host update
:   Rolls a changed session host configuration out to the existing hosts in batches. [Session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update)

Settings catalog
:   The Intune profile type used to configure device and user settings on multi-session hosts. [Windows Enterprise multi-session with Intune](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session)

SignTool
:   Windows SDK command-line tool that signs app packages with a certificate, and can add a timestamp. [Sign an app package using SignTool](https://learn.microsoft.com/windows/msix/package/sign-app-package-using-signtool)

Single sign-on
:   Signs users in to the session host with Microsoft Entra authentication, so they don't sign in twice. [Configure single sign-on](https://learn.microsoft.com/azure/virtual-desktop/configure-single-sign-on)

Start VM on Connect
:   Lets a user's connection start a session host that's turned off. [Start VM on Connect](https://learn.microsoft.com/azure/virtual-desktop/start-virtual-machine-connect)

Storage File Data SMB Share Contributor
:   Built-in role that gives read, write and delete access to an Azure file share over SMB. [Assign share-level permissions](https://learn.microsoft.com/azure/storage/files/storage-files-identity-assign-share-level-permissions)

STUN and TURN
:   Simple Traversal Underneath NAT and Traversal Using Relay NAT. These are the protocols RDP Shortpath uses for direct and relayed UDP connections on public networks. [RDP Shortpath](https://learn.microsoft.com/azure/virtual-desktop/rdp-shortpath)

## T to Z

Ticket-granting ticket (TGT)
:   The Kerberos ticket a user gets at sign-in and then uses to request service tickets without entering credentials again. [Kerberos authentication overview](https://learn.microsoft.com/windows-server/security/kerberos/kerberos-authentication-overview)

Timestamp (code signing)
:   A trusted time added when a package is signed, so the signature stays valid after the certificate expires. Learn recommends timestamping App Attach packages. [App Attach overview](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

Trusted certificate profile (Intune)
:   An Intune configuration profile that installs a root or intermediate certificate on devices, so they trust certificates issued from it. [Trusted root certificate profiles](https://learn.microsoft.com/intune/device-configuration/certificates/trusted-root-profiles)

Trusted launch
:   An Azure VM security type that uses Secure Boot and a virtual TPM. [Trusted launch](https://learn.microsoft.com/azure/virtual-machines/trusted-launch)

Vaulted backup
:   An Azure Files backup tier that copies backup data to a Recovery Services vault, away from the storage account. [About Azure Files backup](https://learn.microsoft.com/azure/backup/azure-file-share-backup-overview)

Virtual Machine User Login
:   Built-in role that lets users sign in to Microsoft Entra joined virtual machines where the host pool requires it. [Microsoft Entra joined session hosts](https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts#assign-user-access-to-host-pools)

Watermarking
:   Shows QR code watermarks containing a connection ID on remote desktops, so captured images can be traced. [Watermarking](https://learn.microsoft.com/azure/virtual-desktop/watermarking)

Windows Cloud Login
:   The Microsoft Entra application involved in signing in to session hosts when single sign-on is enabled. [Enforce MFA with Conditional Access](https://learn.microsoft.com/azure/virtual-desktop/set-up-mfa)

Windows Enterprise multi-session
:   The Windows edition that supports many concurrent user sessions, exclusive to Azure Virtual Desktop. [Windows Enterprise multi-session with Intune](https://learn.microsoft.com/intune/solutions/azure-virtual-desktop-multi-session)

Windows LAPS
:   Windows Local Administrator Password Solution, which can back local administrator passwords up to Microsoft Entra ID. [Windows LAPS with Microsoft Entra ID](https://learn.microsoft.com/windows-server/identity/laps/laps-scenarios-azure-active-directory)

Workspace
:   A logical grouping of application groups that users subscribe to. [AVD terminology](https://learn.microsoft.com/azure/virtual-desktop/terminology#workspaces)

WVDAutoscaleEvaluationPooled
:   Log Analytics table with each autoscale evaluation for a pooled host pool, showing what autoscale decided and why. [Monitor autoscale operations with Insights](https://learn.microsoft.com/azure/virtual-desktop/autoscale-monitor-operations-insights)

WVDConnections, WVDErrors and WVDConnectionNetworkData
:   Azure Virtual Desktop log tables in Log Analytics for connections, errors, and estimated round-trip time and bandwidth. [Diagnostics with Log Analytics](https://learn.microsoft.com/azure/virtual-desktop/diagnostics-log-analytics)
