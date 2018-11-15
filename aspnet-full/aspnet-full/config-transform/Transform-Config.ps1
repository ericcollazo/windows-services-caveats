param (
    [string]$webConfig = "c:\inetpub\wwwroot\web.config",
    [string]$appConfig = "c:\app.config"
)

## Apply config transforms if they exist

$webTransformFile = "c:\web.transform.config";
$appTransformFile = "c:\app.transform.config";

if (Test-Path $webTransformFile) {
    Write-Host "Running web.config transform..."
    \WebConfigTransformRunner.1.0.0.1\Tools\WebConfigTransformRunner.exe $webConfig $webTransformFile $webConfig
    Write-Host "Done!"
}

if (Test-Path $appTransformFile) {
    Write-Host "Running app.config transform..."
    \WebConfigTransformRunner.1.0.0.1\Tools\WebConfigTransformRunner.exe $appConfig $appTransformFile $appConfig
    Write-Host "Done!"
}