// Log analytics workspace. The app's console logs land here.

param name string
param location string
param tags object
param dailyCapGb string

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    workspaceCapping: { dailyQuotaGb: json(dailyCapGb) }
  }
}

output id string = workspace.id
output name string = workspace.name
