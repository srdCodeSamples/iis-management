$serverInfo = Import-Csv -Path "$PSScriptRoot\Resources\WebSiteServersList.csv"

$site = "PCIAPI"
$certThumbprint = "**************" #Make sure set the right one.
$apppool = "$site.AppPool"
$gmsa = "CLOUDAD\sc$site$"
$recycleTime = "5:00"

foreach ($srvInstance in $serverInfo) {
$srv = $srvInstance.Server
$ip = $srvInstance.IP
$ipPrefix = $srvInstance.ipPrefix

Write-Progress -Activity "Configuring $site on $srv" -CurrentOperation "Logging on to $srv"
$ses = New-PSSession -ComputerName $srv

Write-Progress -Activity "Configuring IP: $ip  on $srv"
$ifindex = Invoke-Command -Session $ses {(Get-NetAdapter | where ifDesc -like "vmxnet*").ifIndex}
if ($ifindex.count -eq 1) {
    Invoke-Command -Session $ses {New-NetIPAddress -IPAddress $Args[0] -PrefixLength $Args[1] -InterfaceIndex $Args[2]} -ArgumentList $ip,$ipPrefix,$ifindex
} else {
    Write-Host "There was an error getting the Network Interface on $srv. Either no or more than one interfaces were found. IP is not set!" -ForegroundColor Red
}

Invoke-Command -Session $ses -ScriptBlock {Import-Module WebAdministration}
Write-Progress -Activity "Configuring $site on $srv" -CurrentOperation "Creating WebSite folder"

Invoke-Command -Session $ses {New-Item -Path "D:\Web" -Name $Args[0] -ItemType Directory } -ArgumentList $site

Write-Progress -Activity "Configuring $site on $srv" -CurrentOperation "Creating logs folder"
Invoke-Command -Session $ses {New-Item -Path "E:\Log4Net" -Name $Args[0] -ItemType Directory} -ArgumentList $site
Invoke-Command -Session $ses {
    $accessrule = New-Object system.Security.AccessControl.FileSystemAccessRule($Args[1], "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow");
    $acl = get-acl -Path "E:\Log4Net\$($Args[0])"; $acl.SetAccessRule($accessrule); 
    Set-Acl -Path "E:\Log4Net\$($Args[0])" -AclObject $acl
} -ArgumentList $site,$gmsa

Write-Progress -Activity "Configuring $site on $srv" -CurrentOperation "Creating Application pool"
Invoke-Command -Session $ses {New-WebAppPool -Name $Args[0]} -ArgumentList $apppool

Write-Progress -Activity "Configuring $site on $srv" -CurrentOperation "Setting up Application pool"
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -name processModel -value @{userName=$Args[1];password="";identitytype=3}} -ArgumentList $apppool,$gmsa
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -name recycling.periodicRestart.time -value "0"} -ArgumentList $apppool
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -name recycling.periodicRestart.schedule.Collection -Value @{value="$($Args[1])"}} -ArgumentList $apppool,$recycleTime
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -name Recycling -value @{logEventOnRecycle="Time, Requests, Schedule, Memory, IsapiUnhealthy, OnDemand, ConfigChange, PrivateMemory"}} -ArgumentList $apppool
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -Name managedRuntimeVersion -Value "v4.0"} -ArgumentList $apppool
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -name processModel.idleTimeout -Value "0"} -ArgumentList $apppool

Write-Progress -Activity "Configuring $appname on $srv" -CurrentOperation "Creating Web Site"
Invoke-Command -Session $ses {New-Website -Name $Args[0] -IP $Args[2] -Port 80 -PhysicalPath "D:\Web\$($Args[0])" -ApplicationPool $Args[1]
 } -ArgumentList $site,$apppool,$IP

Write-Progress -Activity "Configuring $appname on $srv" -CurrentOperation "Configuring HTPPS binding"
Invoke-Command -Session $ses {New-WebBinding -Name $Args[0] -IP $Args[1] -Port 443 -Protocol https} -ArgumentList $site,$ip
Invoke-Command -Session $ses {Get-Item -Path "Cert:\LocalMachine\WebHosting\$($Args[1])" | New-Item -Path "IIS:\SslBindings\$($Args[0])!443"} -ArgumentList $ip,$certThumbprint

Write-Progress -Activity "Configuring $appname on $srv" -CurrentOperation "Logging out from $srv"
remove-PSSession $ses
}