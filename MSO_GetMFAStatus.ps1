Import-Module AzureAD
Import-Module MSOnline
if($MSOnlineConnection -eq $null){
    $MSOnlineConnection = Connect-MsolService
}

Function Get-AzureMFAStatus{
    Param(
        [Parameter(Mandatory=$false, HelpMessage = "Enable a full search of all AzureAD Accounts")]$All = $false,
        [Parameter(Mandatory=$false, HelpMessage = "Enter a UserPrincipalName to search")]$UserPrincipalName
    )
    if($All -eq $true){
        $AccountsWithMFA = @()
        $AccountsWithoutMFA = @()
        $AzureMFAStatus = Get-MsolUser -all | select DisplayName,LastPasswordChangeTimestamp,UserPrincipalName,`
                        @{N="MFAStatus"; E={ if( $_.StrongAuthenticationMethods.IsDefault -eq $true)`
                        {($_.StrongAuthenticationMethods|Where IsDefault -eq $True).MethodType} else { "Disabled"}}} 
        foreach($Account in $AzureMFAStatus){
            if($Account.MFAStatus -eq "Disabled"){
                $Info = New-Object -TypeName psobject -Property @{
                    DisplayName = $Account.DisplayName
                    UserPrincipalName = $Account.UserPrincipalName
                    PasswordLastChanged = $Account.LastPasswordChangeTimestamp
                    DefaultMFAMethod = "Unused"
                }
                $AccountsWithoutMFA += $Info
            }else{
                    $Info = New-Object -TypeName psobject -Property @{
                    DisplayName = $Account.DisplayName
                    UserPrincipalName = $Account.UserPrincipalName
                    PasswordLastChanged = $Account.LastPasswordChangeTimestamp
                    DefaultMFAMethod = "Unused"
                    }
                  $AccountsWithMFA += $Info
            }
        }
        return $AccountsWithMFA
    }if($All -eq $false){
            return Get-MsolUser -UserPrincipalName $UserPrincipalName | select DisplayName,LastPasswordChangeTimeStamp,UserPrincipalName,`
                        @{N="MFAStatus"; E={ if( $_.StrongAuthenticationMethods.IsDefault -eq $true)`
                        {($_.StrongAuthenticationMethods|Where IsDefault -eq $True).MethodType} else { "Disabled"}}}
        }
    }


 Function Get-RoleMemberMFAStatus{
        $AzureRoles = Get-MsolRole
        $AzureRoleMembers = @()
        $AzureRoleMemberMFAStatus = @()
        foreach($Role in $AzureRoles){
            $Members = Get-MsolRoleMember -All -RoleObjectId ($Role.ObjectId)
                foreach($Member in $Members){
                $Info = New-Object -TypeName psobject -Property @{
                    RoleName = $Role.Name
                    Member = $Member.DisplayName
                    MemberEmail = $Member.EmailAddress
                }
                $AzureRoleMembers+=$Info
            }
        }
        $UniqueMembers = $AzureRoleMembers.MemberEmail | Group | ? {$_.Count -ge 1} | Select -ExpandProperty Name
        foreach($Member in $UniqueMembers){
            $MFAStatus = (Get-AzureMFAStatus -UserPrincipalName $Member).MFAStatus
            $UserRoles = @()
            foreach($RoleMember in $AzureRoleMembers){
                if(($RoleMember.MemberEmail) -eq $Member){
                    $UserRoles += $RoleMember.RoleName
                    $MemberName = $RoleMember.Member
                }
            }            
            $Info = New-Object -TypeName psobject -Property @{
                MemberName = $MemberName
                MemberEmail = $Member
                MemberRoles = ($UserRoles -join, ";")
                MFAMethod = $MFAStatus
            }
            $AzureRoleMemberMFAStatus += $Info
        }
        return $AzureRoleMemberMFAStatus
    }
