param location string
param hostPoolName string
param hostPoolDeploymentScope string
param appGroupName string
param workspaceName string
param scalingPlanName string
param hostPoolIdentityResourceId string
param sessionHostNamePrefix string
param sessionHostVmSize string
param maxSessionLimit int
param subnetId string
param localAdminUsernameSecretUri string
param localAdminPasswordSecretUri string
param marketplaceImagePublisher string
param marketplaceImageOffer string
param marketplaceImageSku string
param marketplaceImageVersion string
param enrollSessionHostsInIntune bool
param availabilityZones array
param scalingTimeZone string
param rampUpMinimumHostPoolSize int
param rampUpMaximumHostPoolSize int
param rampDownMinimumHostPoolSize int
param rampDownMaximumHostPoolSize int
param pilotUsersGroupObjectId string
param pilotPrincipalType string
param entraSingleSignOn bool
param assignVirtualMachineUserLogin bool
param deployScalingPlan bool
param scalingMethod string
param hostPoolIdentityPrincipalId string
param virtualMachineContributorRoleDefinitionId string
param logAnalyticsWorkspaceId string
param tags object

var desktopVirtualizationUserRoleId = '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63'
var virtualMachineUserLoginRoleId = 'fb879df8-f326-4884-b1cf-06f3ad86be52'
var intuneMdmProviderGuid = '0000000a-0000-0000-c000-000000000000'
// Single sign-on needs Microsoft Entra authentication for RDP enabled in the tenant. Without it, Learn says to add
// targetisaadjoined:i:1 so users sign in to Microsoft Entra joined hosts with their credentials.
// https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts#access-microsoft-entra-joined-vms
var rdpProperties = entraSingleSignOn ? 'enablerdsaadauth:i:1' : 'targetisaadjoined:i:1'

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2026-04-01-preview' = {
  name: hostPoolName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${hostPoolIdentityResourceId}': {}
    }
  }
  properties: {
    friendlyName: 'Contoso North Star pooled host pool'
    description: 'Pilot pooled host pool using session host configuration and dynamic autoscaling.'
    hostPoolType: 'Pooled'
    preferredAppGroupType: 'Desktop'
    loadBalancerType: 'BreadthFirst'
    maxSessionLimit: maxSessionLimit
    managementType: 'Automated'
    deploymentScope: hostPoolDeploymentScope
    validationEnvironment: false
    startVMOnConnect: false
    publicNetworkAccess: 'Enabled'
    customRdpProperty: rdpProperties
    agentUpdate: {
      type: 'Scheduled'
      useSessionHostLocalTime: false
      maintenanceWindowTimeZone: scalingTimeZone
      maintenanceWindows: [
        {
          dayOfWeek: 'Saturday'
          hour: 2
        }
      ]
    }
  }
  tags: tags
}

resource sessionHostConfiguration 'Microsoft.DesktopVirtualization/hostPools/sessionHostConfigurations@2026-04-01-preview' = {
  parent: hostPool
  name: 'default'
  properties: {
    friendlyName: 'Contoso North Star session host configuration'
    vmNamePrefix: sessionHostNamePrefix
    vmLocation: location
    vmResourceGroup: resourceGroup().name
    vmSizeId: sessionHostVmSize
    availabilityZones: availabilityZones
    diskInfo: {
      // Ephemeral OS disk only. The service rejects a managedDisk block alongside diffDiskSettings with
      // MultipleDiskTypesSpecified ('Only one type of OS disk may be specified at one time'), found in live testing.
      // https://learn.microsoft.com/azure/virtual-desktop/deploy/session-hosts/ephemeral-os-disks
      diffDiskSettings: {
        option: 'Local'
        placement: 'TempDisk'
      }
    }
    imageInfo: {
      type: 'Marketplace'
      marketplaceInfo: {
        publisher: marketplaceImagePublisher
        offer: marketplaceImageOffer
        sku: marketplaceImageSku
        exactVersion: marketplaceImageVersion
      }
    }
    // azureActiveDirectoryInfo is optional. When present, the AVD agent enrols each new host in Intune, and a failed
    // enrolment fails provisioning with MdmJoinFailed (found in live testing). Omitting it gives Entra join only.
    // https://learn.microsoft.com/azure/templates/microsoft.desktopvirtualization/hostpools/sessionhostconfigurations
    domainInfo: union({
      joinType: 'AzureActiveDirectory'
    }, enrollSessionHostsInIntune ? {
      azureActiveDirectoryInfo: {
        mdmProviderGuid: intuneMdmProviderGuid
      }
    } : {})
    networkInfo: {
      subnetId: subnetId
    }
    securityInfo: {
      type: 'TrustedLaunch'
      secureBootEnabled: true
      vTpmEnabled: true
    }
    bootDiagnosticsInfo: {
      enabled: true
    }
    vmAdminCredentials: {
      usernameKeyVaultSecretUri: localAdminUsernameSecretUri
      passwordKeyVaultSecretUri: localAdminPasswordSecretUri
    }
    vmTags: tags
  }
}

// The session host management policy is required before dynamic autoscaling can create hosts.
// Template reference: https://learn.microsoft.com/azure/templates/microsoft.desktopvirtualization/hostpools/sessionhostmanagements
// Portal defaults: https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches#session-host-management-policy
resource sessionHostManagement 'Microsoft.DesktopVirtualization/hostPools/sessionHostManagements@2026-04-01-preview' = {
  parent: hostPool
  name: 'default'
  properties: {
    scheduledDateTimeZone: scalingTimeZone
    update: {
      maxVmsRemoved: 1
      logOffDelayMinutes: 2
      logOffMessage: 'You will be signed out'
      deleteOriginalVm: false
    }
    failedSessionHostCleanupPolicy: 'KeepAll'
    provisioning: {
      instanceCount: max(1, rampUpMinimumHostPoolSize)
      setDrainMode: false
    }
  }
  dependsOn: [
    sessionHostConfiguration
  ]
}

resource desktopApplicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2026-04-01-preview' = {
  name: appGroupName
  location: location
  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.id
    friendlyName: 'Contoso pilot desktop'
    description: 'Desktop application group for the North Star pilot.'
  }
  tags: tags
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2026-04-01-preview' = {
  name: workspaceName
  location: location
  properties: {
    friendlyName: 'Contoso North Star workspace'
    description: 'Workspace for the North Star pilot desktop.'
    publicNetworkAccess: 'Enabled'
    applicationGroupReferences: [
      desktopApplicationGroup.id
    ]
  }
  tags: tags
}

resource scalingPlan 'Microsoft.DesktopVirtualization/scalingPlans@2026-04-01-preview' = if (deployScalingPlan) {
  name: scalingPlanName
  location: location
  properties: {
    friendlyName: 'Contoso weekday autoscaling'
    description: 'Autoscaling schedule for the North Star pilot.'
    timeZone: scalingTimeZone
    exclusionTag: 'excludeFromScaling'
    hostPoolType: 'Pooled'
    hostPoolReferences: [
      {
        hostPoolArmPath: hostPool.id
        scalingPlanEnabled: true
      }
    ]
    schedules: [
      union({
        name: 'weekdays'
        daysOfWeek: [
          'Monday'
          'Tuesday'
          'Wednesday'
          'Thursday'
          'Friday'
        ]
        rampUpStartTime: {
          hour: 7
          minute: 0
        }
        rampUpLoadBalancingAlgorithm: 'BreadthFirst'
        rampUpMinimumHostsPct: 100
        rampUpCapacityThresholdPct: 80
        peakStartTime: {
          hour: 9
          minute: 0
        }
        peakLoadBalancingAlgorithm: 'BreadthFirst'
        rampDownStartTime: {
          hour: 17
          minute: 0
        }
        rampDownLoadBalancingAlgorithm: 'DepthFirst'
        // PowerManage stops idle hosts after hours. Dynamic autoscaling sizes the pool with createDelete instead.
        rampDownMinimumHostsPct: scalingMethod == 'PowerManage' ? 0 : 100
        rampDownCapacityThresholdPct: 70
        rampDownForceLogoffUsers: false
        rampDownWaitTimeMinutes: 30
        rampDownNotificationMessage: 'This host is scheduled for maintenance. Save your work and sign out when ready.'
        rampDownStopHostsWhen: 'ZeroSessions'
        offPeakStartTime: {
          hour: 20
          minute: 0
        }
        offPeakLoadBalancingAlgorithm: 'DepthFirst'
        scalingMethod: scalingMethod
      }, scalingMethod == 'CreateDeletePowerManage' ? {
        createDelete: {
          rampUpMinimumHostPoolSize: rampUpMinimumHostPoolSize
          rampUpMaximumHostPoolSize: rampUpMaximumHostPoolSize
          rampDownMinimumHostPoolSize: rampDownMinimumHostPoolSize
          rampDownMaximumHostPoolSize: rampDownMaximumHostPoolSize
        }
      } : {})
    ]
  }
  tags: tags
  dependsOn: [
    sessionHostManagement
  ]
}

resource usersDesktopVirtualizationUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(desktopApplicationGroup.id, pilotUsersGroupObjectId, desktopVirtualizationUserRoleId)
  scope: desktopApplicationGroup
  properties: {
    principalId: pilotUsersGroupObjectId
    principalType: pilotPrincipalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', desktopVirtualizationUserRoleId)
  }
}

// Learn: for Microsoft Entra joined VMs in host pools using a session host configuration, Virtual Machine User Login
// "isn't required". It's offered as a safeguard for credential sign-in and stays off by default.
// https://learn.microsoft.com/azure/virtual-desktop/azure-ad-joined-session-hosts#assign-user-access-to-host-pools
resource usersVirtualMachineUserLogin 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignVirtualMachineUserLogin) {
  name: guid(resourceGroup().id, pilotUsersGroupObjectId, virtualMachineUserLoginRoleId)
  scope: resourceGroup()
  properties: {
    principalId: pilotUsersGroupObjectId
    principalType: pilotPrincipalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', virtualMachineUserLoginRoleId)
  }
}

resource hostPoolIdentityVmContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, hostPoolIdentityPrincipalId, virtualMachineContributorRoleDefinitionId)
  scope: resourceGroup()
  properties: {
    principalId: hostPoolIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', virtualMachineContributorRoleDefinitionId)
  }
}

resource hostPoolDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-log-analytics'
  scope: hostPool
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource appGroupDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-log-analytics'
  scope: desktopApplicationGroup
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-log-analytics'
  scope: workspace
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource scalingDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployScalingPlan) {
  name: 'send-to-log-analytics'
  scope: scalingPlan
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

output hostPoolName string = hostPool.name
output workspaceName string = workspace.name
output desktopApplicationGroupName string = desktopApplicationGroup.name
output scalingPlanName string = deployScalingPlan ? scalingPlanName : ''
