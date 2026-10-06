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

Azure Compute Gallery
:   Azure service for managing, versioning and replicating VM images through image definitions and image versions. [Azure Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/azure-compute-gallery)

Azure Files provisioned v2
:   Azure Files billing model where you provision storage, IOPS and throughput explicitly. [Azure Files billing](https://learn.microsoft.com/azure/storage/files/understanding-billing#provisioned-v2-model)

Azure Image Builder
:   Managed Azure service that builds customised VM images from a template. Also called Azure VM Image Builder. [Azure Image Builder overview](https://learn.microsoft.com/azure/virtual-machines/image-builder-overview)

Azure Monitor Agent
:   The agent that collects guest operating system data from virtual machines for Azure Monitor. [Azure Monitor Agent](https://learn.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-overview)

AVD Insights
:   Azure Monitor workbook for understanding an Azure Virtual Desktop environment: connections, hosts, sign-in performance and more. [AVD Insights](https://learn.microsoft.com/azure/virtual-desktop/insights)

## B to C

Breadth-first
:   Load-balancing algorithm that spreads new sessions across the available session hosts. [Configure host pool load balancing](https://learn.microsoft.com/azure/virtual-desktop/configure-host-pool-load-balancing)

Capacity threshold
:   The percentage of used host pool capacity that triggers a scaling action. [Create and assign a scaling plan](https://learn.microsoft.com/azure/virtual-desktop/autoscale-create-assign-scaling-plan)

CimFS
:   Composite Image File System. The disk image type Learn recommends for App Attach, because it mounts and unmounts faster than VHD or VHDX. [App Attach in AVD](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

Cloud Cache
:   FSLogix capability that writes profile containers to more than one storage location for resilience. [FSLogix business continuity](https://learn.microsoft.com/fslogix/concepts-container-recovery-business-continuity)

Conditional Access
:   Microsoft Entra policies applied at sign-in, such as requiring MFA. With single sign-on, target both **Azure Virtual Desktop** and **Windows Cloud Login**. [Enforce MFA with Conditional Access](https://learn.microsoft.com/azure/virtual-desktop/set-up-mfa)

Custom image template
:   Azure Virtual Desktop feature, built on Azure Image Builder, that defines a source image, customisations and where the built image goes. [Custom image templates](https://learn.microsoft.com/azure/virtual-desktop/custom-image-templates)

## D to E

Data collection rule
:   Azure Monitor object that defines what data is collected and where it's sent. [Data collection rules](https://learn.microsoft.com/azure/azure-monitor/data-collection/data-collection-rule-overview)

Depth-first
:   Load-balancing algorithm that fills one session host to its maximum session limit before using the next. [Configure host pool load balancing](https://learn.microsoft.com/azure/virtual-desktop/configure-host-pool-load-balancing)

Desktop Virtualization User
:   Built-in role that lets users use the desktop or applications in an application group. [Built-in roles for AVD](https://learn.microsoft.com/azure/virtual-desktop/rbac#desktop-virtualization-user)

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

Host pool
:   A collection of Azure virtual machines registered to Azure Virtual Desktop as session hosts. Pooled host pools share hosts between users. Personal host pools give each user their own. [AVD terminology](https://learn.microsoft.com/azure/virtual-desktop/terminology#host-pools)

## I to L

Image definition and image version
:   Azure Compute Gallery objects. A definition describes an image family, and a version is a specific build you deploy. [Azure Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/azure-compute-gallery)

Kerberos server object
:   An object created in Active Directory Domain Services so that Entra joined and hybrid joined session hosts using single sign-on can get Kerberos tickets for on-premises resources. [Create a Kerberos server object](https://learn.microsoft.com/azure/virtual-desktop/configure-single-sign-on#create-a-kerberos-server-object)

Kerberos/CloudKerberosTicketRetrievalEnabled
:   The policy setting that lets session hosts retrieve Microsoft Entra Kerberos tickets for Azure Files. Set it to `1` through the Intune settings catalog. [Enable Microsoft Entra Kerberos for Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable)

Log on blocking registration
:   App Attach registration mode where assigned applications are fully registered during sign-in. [App Attach in AVD](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

## M

Managed identity (host pool)
:   An identity on the host pool that Azure Virtual Desktop uses for session host configuration, autoscale and Start VM on Connect. [Configure managed identity](https://learn.microsoft.com/azure/virtual-desktop/configure-managed-identity)

Max session limit
:   The maximum number of sessions a session host accepts. Autoscale needs a custom value, not the default. [Configure host pool load balancing](https://learn.microsoft.com/azure/virtual-desktop/configure-host-pool-load-balancing)

Microsoft Entra joined session host
:   A session host joined directly to Microsoft Entra ID instead of Active Directory Domain Services. [Microsoft Entra joined session hosts](https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts)

Microsoft Entra Kerberos
:   Lets Microsoft Entra ID issue Kerberos tickets for SMB access to Azure Files, so Entra joined hosts can reach profile shares. [Azure Files identity-based access](https://learn.microsoft.com/azure/storage/files/storage-files-active-directory-overview)

Minimum percentage of active hosts
:   The percentage of the minimum host pool size that autoscale keeps available in a phase. Learn recommends 100% for host pools with ephemeral OS disks. [Ephemeral OS disks on AVD](https://learn.microsoft.com/azure/virtual-desktop/deploy/session-hosts/ephemeral-os-disks)

MSIX
:   The modern Windows application package format, and the long-term format for App Attach. [App Attach in AVD](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

MSIX Packaging Tool and MSIXMGR tool
:   Microsoft tools for creating MSIX packages, and for turning them into CimFS or VHDX images for App Attach. [Create an MSIX image](https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image)

Multimedia redirection
:   Redirects video playback and calls in the browser to the local device for processing. [Multimedia redirection](https://learn.microsoft.com/azure/virtual-desktop/multimedia-redirection-video-playback-calls)

## N to R

NTLMv1
:   A legacy authentication protocol version, removed from Windows 11 version 24H2 and Windows Server 2025. [Removed features](https://learn.microsoft.com/windows/whats-new/removed-features)

On-demand registration
:   App Attach registration mode where full registration of an application is deferred until it's launched. [App Attach in AVD](https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview)

Power management autoscaling
:   Scaling method that powers existing session hosts on and off. Use it with standard management host pools. [Autoscale glossary](https://learn.microsoft.com/azure/virtual-desktop/autoscale-glossary)

Private endpoint
:   A private IP address inside a virtual network for reaching an Azure service, such as Azure Files. [Azure Files network endpoints](https://learn.microsoft.com/azure/storage/files/storage-files-networking-endpoints)

RDP Multipath
:   Monitors several network paths for a session and switches to the most reliable one, reducing disconnections. [RDP Multipath](https://learn.microsoft.com/azure/virtual-desktop/rdp-multipath)

RDP properties
:   Host pool settings that control session behaviour, including single sign-on and device redirection. [Supported RDP properties](https://learn.microsoft.com/azure/virtual-desktop/rdp-properties)

RDP Shortpath
:   A UDP-based transport between the client and the session host, which improves on the default TCP connection. On public networks it uses STUN for direct paths and TURN for relayed ones. [RDP Shortpath](https://learn.microsoft.com/azure/virtual-desktop/rdp-shortpath)

Regional host pool
:   A host pool whose metadata is stored in the selected Azure region rather than in a geographical database shared across regions. [Regional host pools](https://learn.microsoft.com/azure/virtual-desktop/regional-host-pools)

Reverse connect
:   The connection model where session hosts and clients connect out to the Azure Virtual Desktop gateway, so session hosts need no inbound ports. [AVD network connectivity](https://learn.microsoft.com/azure/virtual-desktop/network-connectivity#reverse-connect-transport)

## S

Scaling plan
:   The Azure resource that defines scaling schedules and behaviour for one or more host pools. [Autoscale scenarios](https://learn.microsoft.com/azure/virtual-desktop/autoscale-scenarios)

Screen capture protection
:   Stops remote content being captured in screenshots or screen sharing on supported clients. [Screen capture protection](https://learn.microsoft.com/azure/virtual-desktop/screen-capture-protection)

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

Single sign-on
:   Signs users in to the session host with Microsoft Entra authentication, so they don't sign in twice. [Configure single sign-on](https://learn.microsoft.com/azure/virtual-desktop/configure-single-sign-on)

Start VM on Connect
:   Lets a user's connection start a session host that's turned off. [Start VM on Connect](https://learn.microsoft.com/azure/virtual-desktop/start-virtual-machine-connect)

Storage File Data SMB Share Contributor
:   Built-in role that gives read, write and delete access to an Azure file share over SMB. [Assign share-level permissions](https://learn.microsoft.com/azure/storage/files/storage-files-identity-assign-share-level-permissions)

STUN and TURN
:   Simple Traversal Underneath NAT and Traversal Using Relay NAT. These are the protocols RDP Shortpath uses for direct and relayed UDP connections on public networks. [RDP Shortpath](https://learn.microsoft.com/azure/virtual-desktop/rdp-shortpath)

## T to Z

Trusted launch
:   An Azure VM security type that uses Secure Boot and a virtual TPM. [Trusted launch](https://learn.microsoft.com/azure/virtual-machines/trusted-launch)

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

WVDConnections, WVDErrors and WVDConnectionNetworkData
:   Azure Virtual Desktop log tables in Log Analytics for connections, errors, and estimated round-trip time and bandwidth. [Diagnostics with Log Analytics](https://learn.microsoft.com/azure/virtual-desktop/diagnostics-log-analytics)
