
function Get-AzureADDeviceOwnership
{
	<#
	.SYNOPSIS
	This function  will grab all the Azure AD Users, then query for any assigned 
	devices. It will return all assigned devices in a hastable. You can optionally
	filter for Orphaned (devices with disabled owners) or inactive devices.

	.DESCRIPTION
	Get-AzureADDeviceOwnership returns a list of Azure AD devices along with their
	ownership information. Returns a Hashtable.

	.PARAMETER OnlyOrhpans
	This parameter is used to filter only orphans. Useful for when you're getting a 
	list of devices that exist in Azure, but whose owners are no longer enabled. This
	is a switch, defaulting to $false. Ignored if OnlyActive is set to $true.

	.PARAMETER OnlyInactive
	This parameter is used to filter only inactive devices. Useful for when you're
	getting a list of devices which haven't been used in the last 90 days. This is
	a switch, default to $false. Overrides the OnlyOrphans filter when set, and will
	show all devices which have not been active within the last 90 days, regardless
	of ownership.

	.EXAMPLE
	Get-AzureADDeviceOwnership 
	Returns all Azure AD devices, with ownership information.

	Get-AzureADDeviceOwnership -OnlyOrphans $true
	Returns all Azure AD devices, with ownership information whose owner is no longer
	active.

	Get-AzureADDeviceOwnership -OnlyInactive $true
	Returns all Azure AD devices, with ownership information which have not checked in
	within 90 days.

	#>
	Param
	(
		[switch]$OnlyOrphans = $false,
		[switch]$OnlyInactive = $false
	)
	$AzureADDevices = @()
	$AzureADUsers = Get-AzureADUser -All $true -Filter "UserType eq 'member'"
	ForEach( $User in $AzureADUsers )
	{	
		$Devices = Get-AzureADUserRegisteredDevice -ObjectId $User.ObjectId 
		ForEach( $Device in $Devices )
		{
			$Information = [PSCustomObject] @{
				DeviceName = $Device.DisplayName
				DeviceOwner = $User.DisplayName
				DeviceOwnerEmail = $User.Mail
				DeviceOwnerEnabled = $User.AccountEnabled
				DeviceId = $Device.DeviceId
				DeviceObjectId = $Device.ObjectId
				DeviceOSType = $Device.DeviceOSType
				DeviceOSVersion = $Device.DeviceOSVersion
				DeviceIsManaged = $Device.IsManaged
				DeviceTrustType = $Device.DeviceTrustType
				DeviceLastLogonTimestamp = $Device.ApproximateLastLogonTimestamp
			}
			$AzureADDevices += $Information
		}
	}
	if( ( $OnlyOrphans -eq $true ) -and ( $OnlyInactive -ne $true ) )
	{
		$AzureADOrphanedDevices = $AzureADDevices | Select * | Where { $_.DeviceOwnerEnabled -eq $false }
		return $AzureADOrphanedDevices
	}
	elseif ( $OnlyInactive -eq $true )
	{
		$InactiveDevices = @()
		ForEach ( $Device in $AzureADDevices )
		{
			$TodaysDate = Get-Date
			$LastLogonDate = Get-Date $Device.DeviceLastLogonTimestamp
			if( ( $TodaysDate - $LastLogonDate ).Days -ge 180 )
			{
				$InactiveDevices += $Device
			}
		}
		return $InactiveDevices	
	}
	else 
	{
		return $AzureADDevices
	}
}





function Get-AzureADUserLastLogin{
	<#
	.SYNOPSIS
	This function  will grab all the user accounts in Azure AD, calculate their
	last login date, and format it in usable manner.

	.DESCRIPTION
	Get-AzureADLastLogin returns the last login date and days since last login for
	all users matching a specified query.

	.PARAMETER Output
	Use this paramater to specify a location and file name for where the Report
	should be exported. The report will be exported in CSV Format if this paramater
	is specified. If this parameter is not specified, we will return an array of users

	.PARAMETER FilterGuests
	This parameter is a switch that can be activated. When activated we will Filter
	out all guests accounts.If an advanced filter is specified, this parameter will
	not be used.

	.PARAMETER AdvancedUserFilter
	This paramater should be a filter which would be valid if using the function
	Get-AzureADUser. An example of this would be "UserType eq 'Member'"

	.EXAMPLE
	Get-AzureADLastLogin -FilterGuests $true
	Returns all accounts which aren't a guest account, returns to an array.

	#>
	param (
		[string]$Output,
		[switch]$FilterGuests,
		[string]$AdvancedUserFilter
	)
	if( ( $FilterGuests -eq $true ) -and ( ($AdvancedUserFilter).Length -eq 0 ) ) {
	 $AllUsers = Get-AzureADUser -All $true -Filter "UserType eq 'Member'"
	}elseif( ($AdvancedUserFilter).Length -gt 0 ) {
		try{
			$AllUSers = Get-AzureADUser -All $true -Filter $AdvancedUserFilter
		}catch{
			Write-Host "The filter provided was not a valid filter...quitting..."
			return $false;
		}
	}else{
		$AllUsers = Get-AzureADUser -All $true
	}
	$Today = (Get-Date)
	$Global:UserLastLogings = $AllUsers | ForEach-Object {
		$TimeStamp = $_.RefreshTokensValidFromDateTime
		$TimeStampString = $TimeStamp.ToString()
		[int]$LogonAge = [math]::Round(($Today - $TimeStamp).TotalDays)
		[int]$StaleAge = $MaxInactiveTime + $StaleAgeInDays
		$User = $($_.Mail)
		[pscustomobject]@{
				User		= $($User)
				ObjectID 	= $_.ObjectID
				LastLogon	= $TimeStamp
				DaysSinceLastLogon = $LogonAge
				UserIsStaleAfterThisManyDays = $StaleAge
				UserType = $_.UserType
		}
	}
	if( ($Output).Length -gt 0 ) {
		$UserLastLogings | Export-Csv -NoTypeInformation -Path $Output
		Write-Host "The file was exported to $Output"
		return $true
	}else{
		return $UserLastLogings
	}
}

function Get-UnifiedGroupsOwned
{
    Param
    (
        [string]$Username,
        [switch]$ShowOrphans = $true
    )
    $OwnedGroups = @()
    $UnifiedGroups = Get-UnifiedGroup | Select-Object DisplayName
    $NumberOfGroups = $UnifiedGroups.Count
    $x = 1
    foreach ( $Group in $UnifiedGroups )
    {
        Write-Progress -Activity "Searching groups for owner of $Username" -Status "$x of $NumberOfGroups Groups Searched" -PercentComplete ( ( $x / $NumberOfGroups ) * 100 ) 
        $Owner = $null
        $Owner = Get-UnifiedGroupLinks -LinkType Owners -Identity $Group.DisplayName | 
                Select-Object Name | 
                Where-Object { $_.Name -eq $Username }
        if( ( $Owner -ne $null ) -and ( $Owner -ne "" ) )
        {
            $OwnerCount = (Get-UnifiedGroupLinks -LinkType Owners -Identity $Group.DisplayName).Count
            $Information = [PSCustomObject] @{
                GroupName = $Group.DisplayName
                OwnerName = $Owner.Name
                TotalOwners = $OwnerCount
            }
            if ( ( $ShowOrphans -eq $true ) -or ( ( $OwnerCount-1 ) -gt 0 ) ){
                $OwnedGroups += $Information
            }
        }
        $x++
    }
    return $OwnedGroups
}

function Set-MailboxHiddenFromGAL
{
    Param
    (
       [Switch]$Hypothetical,
       [Switch]$ShowResourceAccounts,
       $UserPrincipalName
    )
    if( $UserPrincipalName.length -gt 0 ){
        if( $Hypothetical )
        {
            $Mailbox = Get-Mailbox $UserPrincipalName `
						Select DisplayName,UserPrincipalName,AccountDisabled,HiddenFromAddressListsEnabled
            $Account = $Mailbox.UserPrincipalName
            $CurrentValue = $Mailbox.HiddenFromAddressListsEnabled
            Write-Warning "Would have set account: $Account HiddenFromAddressListsEnabled from: $CurrentValue to $true"
        }
        else
        {
            Get-Mailbox $UserPrincipalName | Set-Mailbox -HiddenFromAddressListsEnabled $true
            Write-Warning "Set $UserPrincipalName to be hidden from the GAL"
        }
    }else{
        if( $ShowResourceAccounts )
        {
            $MailboxAccounts = Get-Mailbox |
						where { ( $_.AccountDisabled -eq $true ) -and ( $_.HiddenFromAddressListsEnabled -eq $false ) } |
					  Select DisplayName,UserPrincipalName,AccountDisabled,HiddenFromAddressListsEnabled
        }
        else
        {
            $MailboxAccounts = Get-Mailbox | `
						where { ( $_.AccountDisabled -eq $true ) -and `
						( $_.HiddenFromAddressListsEnabled -eq $false ) `
						-and ( $_.RecipientTypeDetails -notin "SharedMailbox", "EquipmentMailbox", "RoomMailbox" ) } |
						Select DisplayName,UserPrincipalName,AccountDisabled,HiddenFromAddressListsEnabled
        }
        if( $Hypothetical )
        {
            foreach( $Mailbox in $MailboxAccounts )
            {
                $CurrentValue = $Mailbox.HiddenFromAddressListsEnabled
                $Account = $Mailbox.UserPrincipalName
                Write-Warning "Would have set account: $Account HiddenFromAddressListsEnabled from: $CurrentValue to $true"
            }
            return $MailboxAccounts
        }
        else
        {
            $AccountCount = $MailboxAccounts.Count()
            Write-Warning "Hid $AccountCount accounts from the GAL";
            return $MailboxAccounts
        }
    }

}
