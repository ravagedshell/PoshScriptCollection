
$EC2Data = @()
$EC2Instances = (Get-EC2Instance).Instances
foreach( $Instance in $EC2Instances )
{
    $ENIData = Get-EC2NetworkInterface | Select * | Where { $_.Attachment.InstanceId -eq $Instance.InstanceId }
    $ENITag = New-Object Amazon.EC2.Model.Tag 
    $ENITag.Key = "Name"
    $ENITag.Value = "$EC2Name-eni"
    $EC2Name = (Get-Ec2Tag | Select Key,Value,ResourceId | Where { ( $_.ResourceId -eq $Instance.InstanceId ) -and ( $_.Key -eq "Name" ) }).Value
    if ( ( $Instance.PublicIpAddress -ne $null ) -and ( $Instance.PublicIpAddress -ne "" ) )
    {   
        $EIPData = Get-EC2Address -PublicIp $Instance.PublicIpAddress
        $EIPTag = New-Object Amazon.EC2.Model.Tag 
        $EIPTag.Key = "Name"
        $EIPTag.Value = "$EC2Name-eip"
        New-EC2Tag -Resource $EIPData.AllocationId -Tag $EIPTag
    }
    New-EC2Tag -Resource $ENIData.NetworkInterfaceId -Tag $ENITag
}
