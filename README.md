

## Sample Secure Rest API App (.NET 8 and C#)

#### Basic features 

Secure Rest APIs hosted in Azure App Service. This is a sample architecture that you can use as your foundational architectural components: Azure Storage, Azure App Services, Azure Document Intelligence, Azure Cosmos DB. More components will be added later such as integration with Azure Open AI or 3rd party LLMs running in Azure. 

#### Current functionality 

(1) Mortgage Calculation and Estimates

(2) Extract information from Documents using Azure Document Intelligence 

(3) Save mortgage loan application into Azure Blob Storage and Azure Cosmos DB

#### Deploy the architecture with connectivity and security 

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fgailzmicrosoft%2FSampleSecureApiApp%2Fmain%2FDeployment%2Fmain.json)

**Deploy Code from GitHub**

In your local solution directory, change directory to **Deployment**. Run PowerShell script `deploy_zipfile_github.ps1`. It downloads the sample_app.zip file in Deployment directory, saves a temp file (remove it afterwards), and then deploy the temp file (.zip) to App Services.  

**Deploy Code from Local - if you have cloned and updated the code**

In your local solution directory, change directory to **Deployment**. Run PowerShell script `build_zipfile.ps1` to rebuild the solution. Run `deploy_zipfile_local.ps1`  to deploy the new code as .zip file to your app service instance. 

#### **Test the App**

Find the URL of your APP Service in Azure. The API Key is stored in your App Configurator as the value of '`x-api-key`'. When the API client invokes the API, the x-api-key value pair must be constructed in the header. You can use swagger interface to test the APIs on a browner with the address of the App Service [Sample App Services UI](https://your-app-service-instance-name.azurewebsites.net/index.html).

#### **Trouble Shooting**

If you downloaded or cloned the code locally and want to test the code locally first. You need to set up key vault policy to allow you to read the key and secret in the key vault. 

