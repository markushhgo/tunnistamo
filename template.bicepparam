using 'template.bicep'

var prefix = readEnvironmentVariable('RESOURCE_PREFIX')
var sanitizedPrefix = replace(prefix, '-', '')
param apiImageName = 'api'
param apiInternalUrl = '${prefix}-api.azurewebsites.net'
param apiUrl = 'tunnistamo-testi.turku.fi'
param apiWebAppName = '${prefix}-api'
param appInsightsName =  '${prefix}-appinsights'
param cacheName =  '${prefix}-cache'
param containerRegistryName =  '${sanitizedPrefix}registry'
param dbName =  'tunnistamo'
param dbServerName =  '${prefix}-db'
param dbAdminUsername =  'turkuadmin'
param dbUsername =  'tunnistamo-qa'
param keyvaultName =  '${prefix}kv'
param serverfarmPlanName =  'serviceplan'
param storageAccountName =  '${sanitizedPrefix}sa'
param apiOutboundIpName = 'turku-test-tunnistamo-outbound-ip'
param natGatewayName = '${prefix}-nat'
param vnetName =  '${prefix}-vnet'
param workspaceName = '${prefix}-workspace'
