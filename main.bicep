// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2024-04-13'
  owner: 'miztiik@github'
}

targetScope = 'resourceGroup'

// Parameters
param deploymentParams object
param identity_params object
param key_vault_params object

param sa_params object

param laws_params object

param brand_tags object

param dce_params object
param vnet_params object
param vm_params object
param appln_gw_params object

param fn_params object
param svc_bus_params object

param acr_params object
param container_app_params object

param cosmosdb_params object

param date_now string = utcNow('yyyy-MM-dd')

var create_kv = false
var create_dce = false
var create_dcr = false
var create_vnet = true
var create_vm = false

param tags object = union(brand_tags, { last_deployed: date_now })

@description('Create Identity')
module r_uami 'modules/identity/create_uami.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_uami'
  params: {
    deploymentParams: deploymentParams
    identity_params: identity_params
    tags: tags
  }
}

@description('Add Permissions to User Assigned Managed Identity(UAMI)')
module r_add_perms_to_uami 'modules/identity/assign_perms_to_uami.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_perms_provider_to_uami'
  params: {
    uami_name_akane: r_uami.outputs.uami_name_akane
  }
  dependsOn: [
    r_uami
  ]
}

@description('Create Alert Action Group')
module r_alert_action_grp 'modules/monitor/create_alert_action_grp.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_alert_action_grp'
  params: {
    deploymentParams: deploymentParams
    tags: tags
  }
}

@description('Create the Log Analytics Workspace')
module r_logAnalyticsWorkspace 'modules/monitor/create_log_analytics_workspace.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_la'
  params: {
    deploymentParams: deploymentParams
    laws_params: laws_params
    tags: tags
  }
}

@description('Create Container Registry')
module r_container_registry 'modules/containers/create_container_registry.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_container_registry'
  params: {
    acr_params: acr_params
    deploymentParams: deploymentParams
    tags: tags
    uami_name_akane: r_uami.outputs.uami_name_akane
    logAnalyticsWorkspaceId: r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
  }
}

@description('Create Container App including managed environments')
module r_container_app 'modules/containers/create_container_apps.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_container_app'
  params: {
    container_app_params: container_app_params
    deploymentParams: deploymentParams
    tags: tags
    uami_name_akane: r_uami.outputs.uami_name_akane
    logAnalyticsWorkspaceName: r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceName
    acr_name: r_container_registry.outputs.acr_name
  }
  dependsOn: [
    r_container_registry
    r_add_perms_to_uami
  ]
}

//////////////////////////////////////////
// OUTPUTS                              //
//////////////////////////////////////////

output module_metadata object = module_metadata
