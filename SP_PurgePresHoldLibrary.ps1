function Purge-PreservationHoldLibrary{
    $Completed = @()
    $Errors = @()

    # Check if PnP.PowerShell is installed, install if running as admin
    if( !(Get-InstalledModule -Name PnP.PowerShell) )
    {
        $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
        if( ($Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) )
        {
            try{
                Install-Module -Force -Name PnP.PowerShell -Scope AllUsers
                $ModuleInstalled = $true
                Write-Host "Succesfully installed module 'PnP.PowerShell', continuing script" -ForegroundColor Green
            }
            catch{
                Write-Error "Could not install required module 'PnP.PowerShell' encountered error: $_"  
                $ModuleInstalled = $false
            }
        }
        else
        {
            Write-Error "We need Administrator privileges to install the required modules. Either launch again as Administrator or run the command 'Install-Module PnP.PowerShell -Scope AllUsers' to complete the install"
            $ModuleInstalled = $false
        }
    }
    else
    {
        $ModuleInstalled = $true
    }

    if ( $ModuleInstalled )
    {
        $ListName = "Preservation Hold Library"
        $IsOneDrive = Read-Host -Prompt "Is this a OneDrive Site? (yes or no)"
        $TenantName = Read-Host -Prompt "Enter the SharePoint tenant name"
        $SiteName = Read-Host -Prompt "Enter the site name (/sites/XXX or /personal/XXX)"

        if( $IsOneDrive -like "yes" )
        {
            $TenantName.Replace( "-my.", "" ) >> null
            $Uri = "https://$TenantName-my.sharepoint.com/personal/$SiteName"
            Write-Host "Using the URL: $Uri to connect to and clear a OneDrive Preservation Hold Library" -ForegroundColor Blue
        }
        else 
        {
            $Uri = "https://$TenantName.sharepoint.com/sites/$SiteName"
            Write-Host "Using the URL: $Uri to connect to and clear a SharePoint Online Preservation Hold Library" -ForegroundColor Blue
        }

        Write-Host "Please proceed to the browser pop-up window to complete interactive logon." -ForegroundColor Yellow
        try{
            Connect-PnPOnline -Url $Uri -Interactive
            Write-Host "Connected to SharePoint/OneDrive: $Uri" -ForegroundColor Blue
        }catch{
            Write-Error "Unable to connect to SharePoint, please try again. If the issue persists, contact your administrator."
        }
        Write-Host "Grabbing the first 500 items from the $ListName...this may take a while..." -ForegroundColor Yellow
        Write-Host "We will continue to grab 500 items at a time until there are 0 items left or we have repeated the process 50 times." -ForegroundColor Yellow
        $Items = Get-PnPListItem -List $ListName -PageSize 500
        $Items | Out-File C:\Opt\InitialList.txt
        $Iteration = 1

        while( ($Items.Count -gt 0) -and ($Iteration -le 50)  )
        {
            foreach( $Item in $Items )
            {
                $ItemId = $Item.Id
                try{
                    Remove-PnPListItem -List $ListName -Identity $ItemId -Force
                    Write-Host "Deleted obect with item id: $ItemId from: $ListName on site: $Uri" -ForegroundColor Green
                    $Completed += "Deleted obect with item id: $ItemId from: $ListName on site: $Uri"
                }
                catch{
                    Write-Host "Unable to delete obect with item id: $ItemId from: $ListName on site: $Uri, encountered error: $_" -ForegroundColor Red
                    $Errors += "Unable to delete obect with item id: $ItemId from: $ListNameon site: $Uri, encountered error: $_"
                }
            }
            Write-Host "($Iteration/50) Grabbing the next 500 items from the $ListName...this may take a while..." -ForegroundColor Yellow
            $Items = Get-PnPListItem -List $ListName -PageSize 500
            $Iteration++
        }
    }

    $Errors | Out-File C:\Opt\Errors.txt
    $Completed | Out-File C:\Opt\Completed.txt
}
