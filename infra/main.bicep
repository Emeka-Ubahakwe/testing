// Observability sandbox, first pass: logs, the container apps environment and the test app.
// Everything here gets the tag sandbox=obs, which is how teardown finds it.

@description('Region for everything.')
param location string = 'uksouth'

@description('Full image name with tag, for example ghcr.io/emeka-ubahakwe/obs-sandbox-app:<commit>.')
param image string

@description('Name of the app identity made by bootstrap.bicep.')
param appIdentityName string = 'id-obs-sbx-app'

@description('Send queue_depth and heartbeat every minute while the app is running.')
param emitLoop bool = true

@description('Log analytics daily cap in GB, as text because bicep has no decimals. Collection stops for the day once it is hit.')
param dailyCapGb string = '0.1'

@description('Email for alert notifications. Comes from the ALERT_EMAIL secret.')
param alertEmail string


var tags = { sandbox: 'obs' }

module logs 'modules/logs.bicep' = {
  name: 'logs'
  params: {
    name: 'log-obs-sbx'
    location: location
    tags: tags
    dailyCapGb: dailyCapGb
  }
}

module environment 'modules/environment.bicep' = {
  name: 'environment'
  params: {
    name: 'cae-obs-sbx'
    location: location
    tags: tags
    workspaceName: logs.outputs.name
  }
}

module app 'modules/app.bicep' = {
  name: 'app'
  params: {
    name: 'ca-obs-sbx'
    location: location
    tags: tags
    environmentId: environment.outputs.id
    image: image
    identityName: appIdentityName
    emitLoop: emitLoop
  }
}

module actionGroups 'modules/action-groups.bicep' = {
  name: 'action-groups'
  params: {
    tags: tags
    alertEmail: alertEmail
  }
}

module platformAlerts 'modules/platform-alerts.bicep' = {
  name: 'platform-alerts'
  params: {
    tags: tags
    appId: app.outputs.id
    actionGroupId: actionGroups.outputs.cloudId
  }
}


output appUrl string = 'https://${app.outputs.fqdn}'
output appResourceId string = app.outputs.id
