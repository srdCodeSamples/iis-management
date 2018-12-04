$env = "LT"
$dscData = Import-LocalizedData -BaseDirectory "D:\DSC" -FileName "Config_$env.psd1" 
$webServers = $dscData.allnodes.Where({$PSitem.Role -ne "App" -and $PSitem.NodeName -ne '*'}).NodeName
Invoke-Command -ComputerName $webServers -ScriptBlock {
                            Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.applicationHost/sites/siteDefaults/logFile/customFields" -name "." -value @{logFieldName='X-Forwarded-For';sourceName='X-Forwarded-For';sourceType='RequestHeader'}
                            Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.applicationHost/sites/siteDefaults/logFile/customFields" -name "." -value @{logFieldName='X-Forwarded-IP';sourceName='X-Forwarded-IP';sourceType='RequestHeader'}
}
Invoke-Command -ComputerName $webServers.where({$psitem -like "awscs*"}) -ScriptBlock {
                            Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.applicationHost/sites/siteDefaults/logFile/customFields" -name "." -value @{logFieldName='ctoken';sourceName='ctoken';sourceType='RequestHeader'}
}