// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2024-05-25'
  owner: 'miztiik@github'
}

param deploymentParams object
param tags object

param uami_name_akane string
param logAnalyticsWorkspaceName string

// param container_instance_params object
param acr_name string

@description('Get Log Analytics Workspace Reference')
resource r_logAnalyticsPayGWorkspace_ref 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

@description('Reference existing User-Assigned Identity')
resource r_uami_container_app 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: uami_name_akane
}

@description('Get Container Registry Reference')
resource r_acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: acr_name
}

var _c_grp_name = replace(
  '${deploymentParams.enterprise_name_suffix}-${deploymentParams.loc_short_code}-container_inst-${deploymentParams.global_uniqueness}',
  '_',
  ''
)

resource r_c_grp_producer 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: '${_c_grp_name}-producer'
  location: deploymentParams.location
  tags: tags
  // zones: [ '1' ] //"Availability Zones are not available in location: 'northeurope'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${r_uami_container_app.id}': {}
    }
  }
  properties: {
    containers: [
      {
        name: 'websocket-echo'
        properties: {
          environmentVariables: [
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: r_logAnalyticsPayGWorkspace_ref.properties.customerId
            }
            {
              name: 'APP_ROLE'
              value: 'producer'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: r_uami_container_app.properties.clientId
            }
          ]
          image: '${sys.toLower(acr_name)}.azurecr.io/miztiik/websocket-echo:latest'
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Always'
    imageRegistryCredentials: [
      {
        username: r_acr.listCredentials().username
        server: r_acr.properties.loginServer
        password: r_acr.listCredentials().passwords[0].value
      }
    ]
    diagnostics: {
      logAnalytics: {
        logType: 'ContainerInsights'
        workspaceId: r_logAnalyticsPayGWorkspace_ref.properties.customerId
        workspaceKey: r_logAnalyticsPayGWorkspace_ref.listKeys().primarySharedKey
      }
    }
    ipAddress: {
      type: 'Public'
      dnsNameLabel: '${_c_grp_name}-websocket-echo'
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
      ]
    }
  }
}

// OUTPUTS
output module_metadata object = module_metadata

output fqdn string = r_c_grp_producer.properties.ipAddress.fqdn
