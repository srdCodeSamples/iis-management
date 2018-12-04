$servers = @() # define the server list
    Do
    {
        $prompt = Read-Host -Prompt "Set httpLogging/DontLog value to True or Flase?"
    }
    Until($prompt -in ('True','False'))
    if ($prompt -eq 'True'){$setting = $true} else {$setting = $false}    

    foreach ($srv in $servers) {
        $logg = (Invoke-Command -ComputerName $srv -ScriptBlock {get-WebConfigurationProperty /system.webserver/httpLogging -Name dontLog}).value
        if (!($logg -eq $setting)) {
            Invoke-Command -ComputerName $srv -ScriptBlock {set-WebConfigurationProperty /system.webserver/httpLogging -Name dontLog -value $Args[0]} -ArgumentList $setting 
            Write-Host ("httpLogging/DontLog set to "+$setting+" on "+$srv) -ForegroundColor Green
            } else {
            Write-Host ("httpLogging/DontLog is already set to "+$setting+" on "+$srv) -ForegroundColor Yellow
        }
    }
    Write-Host "Done. Press Enter to exit." -ForegroundColor Green
    Read-Host