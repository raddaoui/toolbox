targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------

param keyVaultName string
param appGatewayCertificateKeyName string
param appGatewayCertificateData string

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
}

resource sslCertSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: appGatewayCertificateKeyName
  properties: {
    value: appGatewayCertificateData
    contentType: 'application/x-pkcs12'
    attributes: {
      enabled: true
    }
  }
}