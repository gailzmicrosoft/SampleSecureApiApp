#how to run: 
# cd Deployment 
# .\build_zipfile.ps1

# set up path
$projectDir = "..\RestAPIs\src"
$outputDir = "..\RestAPIs\deploy"
$scriptPath = (Get-Location).Path

$zipFile = Read-Host -Prompt "Enter the name of the zip file to build and deploy (e.g. sample_app.zip)"

# Remove $zipFile if it exists
$zipFilePath = "$scriptPath\$zipFile"
if (Test-Path $zipFilePath) {
    Remove-Item -Force $zipFilePath
}

# Step 1: Build the project
dotnet publish $projectDir -c Release -o $outputDir

# Step 2: Create a .zip file
Set-Location $outputDir
Compress-Archive -Path * -DestinationPath $zipFilePath

Set-Location $scriptPath 

