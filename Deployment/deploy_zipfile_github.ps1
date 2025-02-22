# how to run: 
# cd Deployment 
# .\deploy_zipfile_github.ps1

# This file is being tested right now. Not working yet

az login

# get user input
$resourceGroup = Read-Host -Prompt "Enter your resource group name"
$appServiceName = Read-Host -Prompt "Enter your app service name"

#az webapp deploy --resource-group $resourceGroup --name $appServiceName --src-path $zipFilePath --type zip

# Use GitHub Zip file 
$zipFilePath = 'https://raw.githubusercontent.com/gailzmicrosoft/SampleSecureApiApp/main/Deployment/sample_app.zip'

# Publish-AzWebApp -ResourceGroupName Default-Web-WestUS -Name MyApp -ArchivePath <zip-package-path>


Publish-AzWebApp -ResourceGroupName $resourceGroup -Name $appServiceName -ArchivePath $zipFilePath

# Error from above command:
#The filename, directory name, or volume label syntax is incorrect. :
#| 'C:\Repos\SampleSecureApiApp\Deployment\https:\raw.githubusercontent.com\gailzmicrosoft\SampleSecureApiApp\main\Deployment\sample_app.zip'


# Not working
#az webapp deploy --clean true --target-path "home/site/wwwroot/" --type zip -g $resourceGroup -n $appServiceName --src-path $zipFilePath
# Error from above command:
#Deploying from local path: https://raw.githubusercontent.com/gailzmicrosoft/SampleSecureApiApp/main/Deployment/sample_app.zip
#Either 'https://raw.githubusercontent.com/gailzmicrosoft/SampleSecureApiApp/main/Deployment/sample_app.zip' is not a valid local file path or you do not have permissions to access it

# Not working 
# az webapp deploy --resource-group $resourceGroup --name $appServiceName --src-path $zipFilePath
# Error from above command:
# Either 'https://raw.githubusercontent.com/gailzmicrosoft/SampleSecureApiApp/main/Deployment/sample_app.zip' is not a valid local file path or you do not have permissions to access it
