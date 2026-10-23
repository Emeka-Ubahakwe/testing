param tags object
param alertEmail string

resource cloud 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-sbx-cloud'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'sbx-cloud'
    enabled: true
    emailReceivers: [
      { name: 'email', emailAddress: alertEmail, useCommonAlertSchema: true }
    ]
  }
}

resource swe 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-sbx-swe'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'sbx-swe'
    enabled: true
    emailReceivers: [
      { name: 'email', emailAddress: alertEmail, useCommonAlertSchema: true }
    ]
  }
}

output cloudId string = cloud.id
output sweId string = swe.id
