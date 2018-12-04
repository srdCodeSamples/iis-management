$servers = (Import-Csv -Path "$PSScriptRoot\Resources\VirtualApplicationServersList.csv").server
$site = ""
$appname = ""
$apppool = "$appname.AppPool"
$gmsa = "DOMAIN\sc$appname$"
$recycleTime = "5:00"

foreach ($srv in $servers) {
Write-Progress -Activity "Configuring $appname on $srv" -CurrentOperation "Logging on to $srv"
$ses = New-PSSession -ComputerName $srv
Invoke-Command -Session $ses -ScriptBlock {Import-Module WebAdministration}

Write-Progress -Activity "Configuring $appname on $srv" -CurrentOperation "Creating application folder"
Invoke-Command -Session $ses {New-Item -Path "D:\Web" -Name $Args[0] -ItemType Directory } -ArgumentList $appname

Write-Progress -Activity "Configuring $appname on $srv" -CurrentOperation "Creating logs folder"
Invoke-Command -Session $ses {New-Item -Path "E:\Log4Net" -Name $Args[0] -ItemType Directory} -ArgumentList $appname

Invoke-Command -Session $ses {
    $accessrule = New-Object system.Security.AccessControl.FileSystemAccessRule($Args[1], "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow");
    $acl = get-acl -Path "E:\Log4Net\$($Args[0])"; $acl.SetAccessRule($accessrule); 
    Set-Acl -Path "E:\Log4Net\$($Args[0])" -AclObject $acl
} -ArgumentList $appname,$gmsa

Write-Progress -Activity "Configuring $appname on $srv" -CurrentOperation "Creating Application pool"
Invoke-Command -Session $ses {New-WebAppPool -Name $Args[0]} -ArgumentList $apppool

Write-Progress -Activity "Configuring $appname on $srv" -CurrentOperation "Setting up Application pool"
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -name processModel -value @{userName=$Args[1];password="";identitytype=3}} -ArgumentList $apppool,$gmsa
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -name recycling.periodicRestart.time -value "0"} -ArgumentList $apppool
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -name recycling.periodicRestart.schedule.Collection -Value @{value="$($Args[1])"}} -ArgumentList $apppool,$recycleTime
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -name Recycling -value @{logEventOnRecycle="Time, Requests, Schedule, Memory, IsapiUnhealthy, OnDemand, ConfigChange, PrivateMemory"}} -ArgumentList $apppool
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -Name managedRuntimeVersion -Value "v4.0"} -ArgumentList $apppool
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -Name managedRuntimeVersion -Value ""} -ArgumentList $apppool
Invoke-Command -Session $ses {Set-ItemProperty "IIS:\AppPools\$($Args[0])" -name processModel.idleTimeout -Value "0"} -ArgumentList $apppool

Write-Progress -Activity "Configuring $appname on $srv" -CurrentOperation "Creating virtual applicaion"
Invoke-Command -Session $ses {New-WebApplication -Site $Args[1] -Name $Args[2] -PhysicalPath "D:\Web\$($Args[2])" -ApplicationPool $Args[0]} -ArgumentList $apppool,$site,$appname

Write-Progress -Activity "Configuring $appname on $srv" -CurrentOperation "Logging out from $srv"
remove-PSSession $ses
}
