// One-time setup. Deploy this once from your PC, before the first GitHub run.
// It makes two identities that stay in place when teardown runs,
// so the role grants an Owner gives them only need doing once.
//
//   id-obs-sbx-ci   GitHub Actions logs in to Azure as this (no passwords stored)
//   id-obs-sbx-app  the test app uses this to send custom metrics

@description('Region for the identities.')
param location string = 'uksouth'

@description('GitHub repo allowed to log in, as owner/name.')
param githubRepo string = 'Emeka-Ubahakwe/testing@1429471440'

var tags = { sandbox: 'bootstrap' }
var githubIssuer = 'https://token.actions.githubusercontent.com'
var audiences = ['api://AzureADTokenExchange']

resource ciIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-obs-sbx-ci'
  location: location
  tags: tags
}

// Lets runs on the main branch log in (deploy and teardown).
resource mainBranch 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: ciIdentity
  name: 'github-main'
  properties: {
    issuer: githubIssuer
    subject: 'repo:${githubRepo}:ref:refs/heads/main'
    audiences: audiences
  }
}

// Lets pull requests log in (what-if only).
// Azure can't create two of these at the same time, so this waits for the first.
resource pullRequests 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: ciIdentity
  name: 'github-pull-request'
  properties: {
    issuer: githubIssuer
    subject: 'repo:${githubRepo}:pull_request'
    audiences: audiences
  }
  dependsOn: [mainBranch]
}

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-obs-sbx-app'
  location: location
  tags: tags
}

// Put these three in GitHub as repo secrets.
output AZURE_CLIENT_ID string = ciIdentity.properties.clientId
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId

// Give these to the Owner for the role grants.
output ciPrincipalId string = ciIdentity.properties.principalId
output appPrincipalId string = appIdentity.properties.principalId
