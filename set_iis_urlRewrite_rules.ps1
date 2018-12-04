$servers = @(Get-Content -Path "$PSScriptRoot\set_iis_urlRewrite_rules_servers.txt")

$serverVar = "HTTP_X_FORWARDED_IP"
$name = 'Insert X-Forwarded-IP'
$inbound = '.*'
$range = '\b(?!10\.|127|(172\.1[6-9]\.)|(172\.2[0-9]\.)|(172\.3[0-1]\.)|(192\.168\.))(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*'
$site = 'IIS:\'
$root = 'system.webServer/rewrite/globalRules'
$filter = "{0}/rule[@name='{1}']" -f $root, $name




foreach ($srv in $servers)
{
       $allwodVars =  @(Invoke-Command -computername $srv -ScriptBlock { Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables | select -ExpandProperty collection | Where-Object {$_.ElementTagName -eq "add"} | select -ExpandProperty name })
        
        if ($serverVar -notin $allwodVars) 
        {
            Write-Host "Adding $serverVar to allowed server variables on $srv"
            Invoke-Command -ComputerName $srv { Add-WebConfiguration /system.webServer/rewrite/allowedServerVariables -AtIndex 0 -value @{name="HTTP_X_FORWARDED_IP"} -Verbose }
        }
        else
        {
            Write-Host "$serverVar was laready in the allowed servers list on $srv" -ForegroundColor Yellow
        }

        $rewriteRules = @(Invoke-Command -ComputerName $srv -ScriptBlock {param($root); Get-WebConfiguration -filter $root | select -ExpandProperty collection | Where-Object {$_.ElementTagName -eq "rule"} } -ArgumentList $root)
        if ($name -notin $rewriteRules.Name)
        {
            Write-Host "Creating rewrite rule on $srv"
            Invoke-Command -ComputerName $srv {
                param($root,$filter,$name,$inbound,$range)
                Add-WebConfigurationProperty -filter $root -name '.' -value @{name=$name; patternSyntax='Regular Expressions'; stopProcessing='False'}
                Set-WebConfigurationProperty -filter "$filter/match" -name 'url' -value $inbound
                Set-WebConfigurationProperty -filter "$filter/conditions" -name '.' -value @{input='{HTTP_X_FORWARDED_FOR}'; matchType='0'; pattern=$range; ignoreCase='True'; negate='False'}
                Set-WebConfigurationProperty -filter "$filter/serverVariables" -name '.' -value @{name='HTTP_X_FORWARDED_IP'; value='{C:5}'; replace='false'}
                Set-WebConfigurationProperty -filter "$filter/action" -name 'type' -value 'None'
            } -ArgumentList $root,$filter,$name,$inbound,$range
        }
        elseif($rewriteRules.where{$Psitem.Name -eq $name}.conditions.collection.pattern -ne $range)
        {
            Write-Host "URLRewrite rule `"$name`" already exists on $srv but IP match pattern is different. Correcting it." -ForegroundColor Yellow
            Invoke-Command -ComputerName $srv {
                param($root,$filter,$name,$inbound,$range)
                Set-WebConfigurationProperty -filter "$filter/match" -name 'url' -value $inbound
                Set-WebConfigurationProperty -filter "$filter/conditions" -name '.' -value @{input='{HTTP_X_FORWARDED_FOR}'; matchType='0'; pattern=$range; ignoreCase='True'; negate='False'}
                Set-WebConfigurationProperty -filter "$filter/serverVariables" -name '.' -value @{name='HTTP_X_FORWARDED_IP'; value='{C:5}'; replace='false'}
                Set-WebConfigurationProperty -filter "$filter/action" -name 'type' -value 'None'
            } -ArgumentList $root,$filter,$name,$inbound,$range
        }
        else
        {
            Write-Host "The same URLRewrite rule `"$name`" already exists on $srv. No changes are made." -ForegroundColor Yellow
        }

}



