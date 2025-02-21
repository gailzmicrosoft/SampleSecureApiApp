# how to run: 
# cd Deployment 
# .\deploy_zipfile_github.ps1

# This file is being tested right now.

az login

# get user input
$resourceGroup = Read-Host -Prompt "Enter your resource group name"
$appServiceName = Read-Host -Prompt "Enter your app service name"

#az webapp deploy --resource-group $resourceGroup --name $appServiceName --src-path $zipFilePath --type zip

# Use GitHub Zip file 
$gitHubZipFilePath = 'https://raw.githubusercontent.com/gailzmicrosoft/SampleApp/main/Deployment/sample_app.zip'

az webapp deployment source config --resource-group $resourceGroup --name $appServiceName --src-path $gitHubZipFilePath --type zip