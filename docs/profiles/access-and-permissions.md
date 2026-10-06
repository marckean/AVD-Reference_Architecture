---
title: Access and permissions
description: Microsoft Entra Kerberos for Azure Files, share-level and NTFS permissions, and the Kerberos setting session hosts need.
---

# Access and permissions

## Identity and permissions

Microsoft Entra Kerberos uses Microsoft Entra ID to issue Kerberos tickets for SMB access. Learn states that Azure Files receives the Kerberos ticket, not the user's access credentials ([Overview of Azure Files identity-based authentication for SMB access](https://learn.microsoft.com/azure/storage/files/storage-files-active-directory-overview)).

Set share-level permissions first, then NTFS permissions. Learn lists these built-in Azure RBAC roles for Azure Files: **Storage File Data SMB Share Reader**, **Storage File Data SMB Share Contributor**, **Storage File Data SMB Share Elevated Contributor**, **Storage File Data Privileged Contributor**, **Storage File Data Privileged Reader**, **Storage File Data SMB Admin**, and **Storage File Data SMB Take Ownership** ([Assign share-level permissions for Azure file shares](https://learn.microsoft.com/azure/storage/files/storage-files-identity-assign-share-level-permissions)).

For FSLogix profile containers, assign users or groups **Storage File Data SMB Share Contributor** at the share level, then set NTFS permissions so users can create and access only their own profile folders. Administrative groups that manage ACLs need **Storage File Data SMB Share Elevated Contributor** or a more privileged role where justified ([Assign share-level permissions for Azure file shares](https://learn.microsoft.com/azure/storage/files/storage-files-identity-assign-share-level-permissions)).

Each session host must be able to retrieve Microsoft Entra Kerberos tickets. Learn requires enabling **Kerberos/CloudKerberosTicketRetrievalEnabled** and setting it to `1`; when using Intune, Learn says to use the **Settings Catalog** instead of the OMA-URI method because OMA-URI does not work on Azure Virtual Desktop multi-session devices ([Enable Microsoft Entra Kerberos authentication for hybrid and cloud-only identities on Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable)).

---

Part of [User profiles with FSLogix](index.md).
