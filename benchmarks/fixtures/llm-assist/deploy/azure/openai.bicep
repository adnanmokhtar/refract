@description('Azure OpenAI account used by the EU data-residency tenants.')
param accountName string = 'qd-openai-weu'
param location string = 'westeurope'

resource account 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: accountName
  location: location
  kind: 'OpenAI'
  sku: { name: 'S0' }
  properties: { customSubDomainName: accountName, publicNetworkAccess: 'Disabled' }
}

resource chat 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: account
  name: 'chat'
  sku: { name: 'GlobalStandard', capacity: 150 }
  properties: {
    model: { format: 'OpenAI', name: 'gpt-4o', version: '2024-11-20' }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}
