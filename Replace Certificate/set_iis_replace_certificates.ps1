#Load Servers from a .csv file
$servers = (Import-Csv -Path "$PSScriptRoot\web_servers.csv").Server

#Load Servers by typing them directly
#$servers = @()

$pfxPassword = (Get-Credential -UserName "DummyCertUser" -Message "Certificate Password").Password

#The name of the Certificate's .pxf MUST BE IN THE SCRIPT'S FOLDER
$pfxCertificateFile = ""
$oldCertThumb = ''
$newCertThumb = ''

$serverFolder = "c:\temp-cert\$pfxCertificateFile"

foreach($srv in $servers)
{
    ##Copy and Install the new certificate. MAKE SURE TO EDIT THE SOURCE AND DESTINATION PATHS
    Write-Host "Copying new cert file to server $srv" -ForegroundColor Yellow
    $sharePath = "\\$srv\$([System.IO.Path]::GetDirectoryName($serverFolder).Replace(':','$'))"
    if(!(Test-Path -Path "$sharePath")) {
          [System.IO.Directory]::CreateDirectory($sharePath)  
    }
    Copy-Item -Path "$PSScriptRoot\$pfxCertificateFile" -Destination "\\$srv\$($serverFolder.Replace(':','$'))" -ErrorAction Inquire
    Write-Host "Installing new cert on $srv" -ForegroundColor Yellow
    Invoke-Command -ComputerName $srv -ScriptBlock { 
                                                     Import-PfxCertificate -FilePath "$($Args[1])" -Password $Args[0] -CertStoreLocation "Cert:\LocalMachine\WebHosting\"; 
                                                     Remove-Item -Path ([System.IO.Path]::GetDirectoryName("$($Args[1])")) -Force -Recurse
    } -ArgumentList $pfxPassword,$serverFolder -ErrorAction Inquire

    Write-Host "Setting new binding on $srv"

    ##Rebind all IIS sites to the new certificate
    Invoke-Command -ComputerName $srv -ScriptBlock {
                                                        Import-Module WebAdministration;
                                                        $oldBindings = Get-ChildItem -Path IIS:\SSlBindings | Where-Object ThumbPrint -eq $Args[0];
                                                        foreach ($bind in $oldBindings)
                                                        {
                                                            Write-Host "Removing binding for $($bind.Sites)" -ForegroundColor Yellow
                                                            $bind | Remove-Item -Force
                                                            Write-host "Setting new binding for $($bind.Sites)" -ForegroundColor Yellow
                                                            Get-Item -Path "Cert:\LocalMachine\WebHosting\$($Args[1])" | New-Item -Path "IIS:\SslBindings\$($bind.IPAddress.IPAddressToString)!$($bind.Port)"
                                                        }
                                                        $checkOldBindings = Get-ChildItem -Path IIS:\SSlBindings | Where-Object ThumbPrint -eq $Args[0];
                                                        if ($checkOldBindings.count -eq 0)
                                                        {
                                                           Write-Host "Removing old certificate" -ForegroundColor Yellow
                                                           Remove-Item -Path "Cert:\LocalMachine\WebHosting\$($Args[0])" -Force
                                                        }
                                                        else
                                                        {
                                                           Write-Host "Old certificate still in use. Skipping remove" -ForegroundColor Red
                                                        }
    } -ArgumentList $oldCertThumb,$newCertThumb -ErrorAction Inquire
}

