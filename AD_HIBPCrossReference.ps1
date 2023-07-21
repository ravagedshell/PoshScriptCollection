$PathToPwnedEmailsList
$PwnedEmails = Import-Csv -Delimiter "`t" $PathToPwnedEmailsList
$Creds = (Get-Credential)
Foreach($User in $PwnedEmails){
    $UserEmail = $User.Email
    $UserBreach = $User.Breach
    $UserIdentity = $UserEmail.trim("@[domain.com]")
    $ADCrossReference = Invoke-Command -ComputerName  [domaincontroller] -Credential $Creds -ScriptBlock { 
        try {
            Get-ADUser -Identity $UserIdentity
        }
        catch {
            Write-Output "Unknown user"
        }
    }
    if($ADCrossReference = "Unknown User"){
        Write-Output "$ADCrossreference with email $UserEmail was a part of breach $UserBreach"
    }else{
        $DisplayName = $ADCrossReference.Name
        Write-Output "$DisplayName with email $UserEmail was a part of breach $UserBreach"
    }
}

