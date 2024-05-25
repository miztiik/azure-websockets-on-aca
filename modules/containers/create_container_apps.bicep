// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2024-04-13'
  owner: 'miztiik@github'
}

param deploymentParams object
param tags object

param uami_name_akane string
param logAnalyticsWorkspaceName string

param container_app_params object
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

var _app_name = replace(
  '${deploymentParams.enterprise_name_suffix}-${deploymentParams.loc_short_code}-${container_app_params.name_prefix}-${deploymentParams.global_uniqueness}',
  '_',
  '-'
)

resource r_mgd_env 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: '${_app_name}-mgd-env'
  location: deploymentParams.location
  tags: tags

  properties: {
    zoneRedundant: false // Available only for Premium SKU
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: r_logAnalyticsPayGWorkspace_ref.properties.customerId
        sharedKey: r_logAnalyticsPayGWorkspace_ref.listKeys().primarySharedKey
      }
    }
  }
}

resource r_container_app_producer 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'c-app-websocket-${deploymentParams.loc_short_code}-${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${r_uami_container_app.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: r_mgd_env.id
    configuration: {
      activeRevisionsMode: 'single'
      secrets: [
        {
          name: 'registry-password'
          value: r_acr.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: '${r_acr.name}.azurecr.io'
          identity: r_uami_container_app.id
        }
      ]
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: []
      }
      containers: [
        {
          env: [
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: r_logAnalyticsPayGWorkspace_ref.properties.customerId
            }
          ]
          name: 'websocket-echo'
          // image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          // image: '${sys.toLower(acr_name)}.azurecr.io/miztiik/echo-hello:latest'
          // image: '${sys.toLower(acr_name)}.azurecr.io/miztiik/flask-web-server:latest'
          // image: '${sys.toLower(acr_name)}.azurecr.io/miztiik/event-producer:latest'
          image: '${sys.toLower(acr_name)}.azurecr.io/miztiik/websocket-echo:latest'
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          probes: []
        }
      ]
    }
  }
}

// OUTPUTS
output module_metadata object = module_metadata

output fqdn string = r_container_app_producer.properties.configuration.ingress.fqdn
output websocket_app_url string = 'https://${r_container_app_producer.properties.configuration.ingress.fqdn}/event-producer'
