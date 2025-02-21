@description('Prefix to use for all resources.')
param resourcePrefixUser string = 'mrtg1'

var trimmedResourcePrefixUser = length(resourcePrefixUser) > 5 ? substring(resourcePrefixUser, 0, 5) : resourcePrefixUser
var uniString = toLower(substring(uniqueString(subscription().id, resourceGroup().id), 0, 5))

var resourcePrefix = '${trimmedResourcePrefixUser}${uniString}'
var location = resourceGroup().location
//var subscriptionId = subscription().id

/**************************************************************************/
// Create a storage account and a container
/**************************************************************************/
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${toLower(resourcePrefix)}storage'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}
// create blob service in the storage account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

// create a container named mortgageapp in the storage account
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'mortgageapp'
  properties: {
    publicAccess: 'None'
  }
}

/**************************************************************************/
// Create a Form Recognizer resource
/**************************************************************************/
resource formRecognizer 'Microsoft.CognitiveServices/accounts@2021-04-30' = {
  name: '${resourcePrefix}FormRecognizer'
  location: location
  kind: 'FormRecognizer'
  sku: {
    name: 'S0'
  }
  properties: {}
}

/**************************************************************************/
// Create a Cosmos DB account
/**************************************************************************/
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: '${toLower(resourcePrefix)}cosmosdbaccount'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
      }
    ]
  }
}

// Create a database in the Cosmos DB account named LoanAppDatabase
resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  parent: cosmosDbAccount
  name: 'LoanAppDatabase'
  properties: {
    resource: {
      id: 'LoanAppDatabase'
    }
  }
}

// Create a container in the Cosmos DB database
resource cosmosDbContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: cosmosDbDatabase
  name: 'LoanAppDataContainer'
  properties: {
    resource: {
      id: 'LoanAppDataContainer'
      partitionKey: {
        paths: [
          '/LoanAppDataId'
        ]
        kind: 'Hash'
        version: 2
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
    }
  }
}

var cosmosDbEndpoint = cosmosDbAccount.properties.documentEndpoint
var formRecognizerEndpoint = formRecognizer.properties.endpoint
var formRecognizerKey = listKeys(formRecognizer.id, '2021-04-30').key1


/**************************************************************************/
// appConfig and appConfig Key Value Pairs
/**************************************************************************/
resource appConfig 'Microsoft.AppConfiguration/configurationStores@2024-05-01' = {
  name: '${resourcePrefix}AppConfig'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {}
  dependsOn: [
    blobContainer
    formRecognizer
    cosmosDbContainer
  ]
}
/*****************************  Key Value Pairs ***************************/
resource appConfigKeyAzureStorageName 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: 'azure-storage-account-name'
  properties: {
     value: storageAccount.name
  }
}
resource appConfigKeyBlobContainer 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: 'azure-storage-blob-container-name'
  properties: {
     value: blobContainer.name
  }
}
resource appConfigKeyCosmosDbEp 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: 'cosmos-db-endpoint'
  properties: {
     value: string(cosmosDbEndpoint)
  }
}
resource appConfigKeyCosmosDbName 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: 'cosmos-db-name'
  properties: {
     value: cosmosDbDatabase.name
  }
}
resource appConfigKeyCosmosDbContainer 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: 'cosmos-db-container-name'
  properties: {
     value: cosmosDbContainer.name
  }
}
resource appConfigKeyFormRecognizerEp 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: 'form-recognizer-endpoint'
  properties: {
     value: string(formRecognizerEndpoint)
  }
}
resource appConfigKeyFormRecognizerKey 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: 'form-recognizer-key'
  properties: {
     value: string(formRecognizerKey)
  }
}

resource appConfigKeyApiKey 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: 'x-api-key'
  properties: {
     value:'AppConfigApiKey'
  }
}

/**************************************************************************/
// App Service Plan and App Service
/**************************************************************************/
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${resourcePrefix}AppServicePlan'
  location: location
  kind: 'linux'
  sku: {
    name: 'B3'
    tier: 'Basic'
    size: 'B3'
    family: 'B'
    capacity: 1
  }
  properties: {
    perSiteScaling: false
    reserved: true
  }

}


resource appService 'Microsoft.Web/sites@2024-04-01' = {
  name: '${resourcePrefix}AppService'
  location: location
  kind: 'app'
  tags:{
    displayName: 'Mortgage Advisor'
    environment: 'test'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    endToEndEncryptionEnabled:false
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'
      appSettings: [
        {
          name:'ENVIRONMENT'
          value:'Release'
        }
        {
          name:'APP_CONFIG_ENDPOINT'
          value: appConfig.properties.endpoint
        }
        {
          name:'AppConfigConnectionString'
          value:'Endpoint=${appConfig.properties.endpoint};Id=${appConfig.id};Secret=${listKeys(appConfig.id, '2024-05-01').value[0]}'
        }
      ]
      healthCheckPath:'/health' // Add this line to enable health check
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}



/**************************************************************************/
// Assign App Service Identity the Contributor role for the Resource Group
/**************************************************************************/
//var resourceGroupContributorRoleID = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var resourceGroupContributorRoleID = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource appServiceRoleAssignmentContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appService.id, 'Contributor')
  scope: resourceGroup()
  properties: {
    //roleDefinitionId: '${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${resourceGroupContributorRoleID}'
    roleDefinitionId: resourceGroupContributorRoleID
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

/**************************************************************************/
// Assign App Service Identity the Storage Blob Data Contributor role for the Storage Account
/**************************************************************************/
//var storageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageBlobDataContributorRoleID = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
resource roleAssignmentStorageBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appService.id, 'StorageBlobDataContributor')
  scope: resourceGroup()
  properties: {
    //roleDefinitionId: '${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${storageBlobDataContributorRoleID}'
    roleDefinitionId: storageBlobDataContributorRoleID
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
    //scope: storageAccount.id
    //scope: resourceGroup().id
  }
}



/**************************************************************************/
// Deploy Code (.zip file) to App Service using deploymentScripts
/**************************************************************************/

// var resourceGroupName = resourceGroup().name
// var appServiceName = appService.name
// var zipFilePath = 'https://raw.githubusercontent.com/gailzmicrosoft/SampleApp/main/Deployment/sample_app.zip'

// resource deployScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
//   name: 'deployScript'
//   location: location
//   kind: 'AzureCLI'
//   properties: {
//     azCliVersion: '2.0.80'
//     scriptContent: '''
//        az webapp deploy --resource-group ${resourceGroupName} --name  ${appServiceName} --src-path ${zipFilePath}
//     '''
//     timeout: 'PT10M'
//     cleanupPreference: 'OnSuccess'
//     retentionInterval: 'P1D'
//   }
//   dependsOn: [
//     appService
//   ]
// }


//https://learn.microsoft.com/en-us/cli/azure/webapp/deployment/source?view=azure-cli-latest#az-webapp-deployment-source-config
//az webapp deployment source config --branch master --manual-integration --name MyWebApp --repo-url https://github.com/Azure-Samples/function-image-upload-resize --resource-group MyResourceGroup



/**************************************************************************/
// Deploy Code (.zip file) to App Service using MSDeploy
/**************************************************************************/

/* This one did not work. Error: No route registered for '/MSDeploy' */

// var zipUrl = 'https://raw.githubusercontent.com/gailzmicrosoft/SampleApp/main/Deployment/sample_app.zip'
// resource zipDeploy 'Microsoft.Web/sites/extensions@2022-09-01' = {
//   name: 'MSDeploy'
//   kind: 'string'
//   parent: appService
//   properties: {
//     packageUri: zipUrl
//   }
// }



// /**************************************************************************/
// // Deploy Code (.zip file) to App Service using ZipDeploy
// /**************************************************************************/

// Code not tested yet 

// var zipFilePath = 'https://raw.githubusercontent.com/gailzmicrosoft/SampleApp/main/Deployment/sample_app.zip'

// resource zipDeploy 'Microsoft.Web/sites/extensions@2022-09-01' = {
//   name: 'ZipDeploy'
//   parent: appService
//   properties: {
//     packageUri: zipFilePath
//   }
// }





///*******************************************************************************************************************/
// Below role assignment are not needed as App Service Identity is already assigned the Contributor role for the Resource Group
/*********************************************************************************************************************/

// /**************************************************************************/
// // Create user-assigned managed identity for the resource group
// /**************************************************************************/
// resource rg_user_identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
//   name: '${resourcePrefixUser}_rg_user_identity'
//   location: location
// }

// /**************************************************************************/
// // Assign CosmosDB Account Contributor to rg_user_identity 
// /**************************************************************************/
// //var cosmosDbContributorRoleID = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// //"id": "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c",
// var cosmosDbContributorRoleID = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

// resource rgIdroleAssignmentCustomRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(rg_user_identity.id, 'cosmosDbContributorRoleID')
//   scope: resourceGroup()
//   properties: {
//     //roleDefinitionId: '${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${cosmosDbContributorRoleID}'
//     roleDefinitionId:cosmosDbContributorRoleID
//     principalId: rg_user_identity.properties.principalId
//     principalType: 'ServicePrincipal'
//     //scope: cosmosDbAccount.id
//    // scope: resourceGroup().id
//   }
//   dependsOn: [
//     cosmosDbAccount
//   ]
// }

