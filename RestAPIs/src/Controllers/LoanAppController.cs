﻿using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using System.Threading.Tasks;
using Azure.Core;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using System;
using RestAPIs.Capabilities;
using System.Data;

namespace RestAPIs.Controllers
{
    //[Authorize]
    [ApiController]
    [Route("[controller]")]
    public class LoanAppController : ControllerBase
    {
        private readonly ILogger<LoanAppController> _logger;
        private readonly IConfiguration _configuration;
        private readonly BlobServiceClient _blobServiceClient;
        private readonly string _azureStorageAccountName;
        private readonly string _azureStorageEndPoint;
        private readonly string _blobContainerName;
        private readonly CosmosClient _cosmosClient;
        private readonly string _cosmosAcountEndPoint;
        private readonly string _cosmosDatabaseName;
        private readonly string _cosmosContainerName;

        public LoanAppController(ILogger<LoanAppController> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;

            var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
            _logger.LogInformation($"Current environment: {environment}");

            TokenCredential credential;
            if (environment == "Development")
            {
                credential = new DefaultAzureCredential();
            }
            else
            {
                credential = new ManagedIdentityCredential();
            }

            // Set up connection to blob storage
            // Add Web App's managed identity to the Storage Blob Data Contributor role in the Azure Storage account
            _azureStorageAccountName = _configuration.GetValue<string>("azure-storage-account-name") ?? throw new ArgumentNullException(nameof(_azureStorageAccountName));
            _azureStorageEndPoint = $"https://{_azureStorageAccountName}.blob.core.windows.net";
            _blobContainerName = _configuration.GetValue<string>("azure-storage-blob-container-name") ?? throw new ArgumentNullException(nameof(_blobContainerName));
            _blobServiceClient = new BlobServiceClient(new Uri(_azureStorageEndPoint), credential);

            // Cosmos DB NoSQL database setup
            //Database Name: LoanAppDatabase
            //Container Name: LoanAppDataContainer
            //Partition key: /LoanAppDataId
            // Permissions to assign to the managed identity:
            // Cosmos DB Account Contributor
            // Cosmos DB Account Reader Role
            // DocumentDB Account Contributor Role
            // Cosmos DB Operator
            //*************** For the web app to work, I added Contributor role for the scope of RG for App Service (Preview)  ***************/
            // Also added a custom role which is quite a bit more work! It seems this is the only role that may be needed. Reference doc here: 
            // https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/security/how-to-grant-data-plane-role-based-access?tabs=built-in-definition%2Ccsharp&pivots=azure-interface-cli


            // Set up access to Cosmos DB Access 
            _cosmosAcountEndPoint = _configuration.GetValue<string>("cosmos-db-endpoint") ?? throw new ArgumentNullException(nameof(_cosmosAcountEndPoint));
            _cosmosDatabaseName = _configuration.GetValue<string>("cosmos-db-name") ?? throw new ArgumentNullException(nameof(_cosmosDatabaseName));
            _cosmosContainerName = _configuration.GetValue<string>("cosmos-db-container-name") ?? throw new ArgumentNullException(nameof(_cosmosContainerName));
            _cosmosClient = new CosmosClient(_cosmosAcountEndPoint, credential);

        }

        [HttpPost("SubmitLoanApplication")]
        public async Task<IActionResult> SubmitLoanApplication([FromBody] LoanAppData loanAppData)
        {
            if (loanAppData == null)
            {
                return BadRequest("Invalid loan application data.");
            }

            try
            {
                // Create a UUID to identify the record
                var uuid = Guid.NewGuid();
                var loanAppDataId = uuid.ToString();

                // Convert current time to US Eastern Time
                var easternZone = TimeZoneInfo.FindSystemTimeZoneById("Eastern Standard Time");
                DateTime currentTime = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, easternZone);

                // Create the JSON object with loanAppData and currentTime
                var dataToStore = new
                {
                    id = loanAppDataId, // Add the id property
                    LoanAppDataId = loanAppDataId, // This was set up in Cosmos DB as the partition key
                    CurrentTime = currentTime,
                    LoanAppData = loanAppData
                };

                var jsonData = JsonSerializer.Serialize(dataToStore);

                // Save the JSON object to Azure Blob Storage
                var blobContainerClient = _blobServiceClient.GetBlobContainerClient(_blobContainerName);
                var blobClient = blobContainerClient.GetBlobClient($"loan_applications/{loanAppData.FirstName}_{loanAppData.MiddleName}_{loanAppData.LastName}_{currentTime:yyyyMMddHHmmss}.json");

                using (var memoryStream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(jsonData)))
                {
                    await blobClient.UploadAsync(memoryStream, true);
                }


                var cosmosContainer = _cosmosClient.GetContainer(_cosmosDatabaseName, _cosmosContainerName);
                await cosmosContainer.CreateItemAsync(dataToStore, new PartitionKey(loanAppDataId));

                return Ok(new { Message = "Loan application submitted successfully.", UUID = uuid });
            }
            catch (CosmosException ex)
            {
                _logger.LogError($"Cosmos DB error: {ex.StatusCode} - {ex.Message}");
                return StatusCode((int)ex.StatusCode, ex.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError($"An error occurred: {ex.Message}");
                return StatusCode(500, $"An internal server error occurred: {ex.Message}");
            }
        }
    }
}
