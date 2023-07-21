###
#
# Author: ravagedshell <github.com/ravagedshell>
# Email: 
#
# TODO:
# Add ability to log in multi-part files for JSON data.
# Add ability to upload to CloudWatch logs.
#
###

Set-StrictMode -Version Latest

function New-LogFile
{
    <#
    .SYNOPSIS
        Creates a new log file

    .DESCRIPTION
        Creates a log file with the path and name specified in the parameters. Checks if log file exists, if it does, generates a new one based off of timestamp. 
        Also allows the generating of logs in multiple format such as CSV, JSON, CloudWatch JSON, and RAW Text.

    .PARAMETER LogFilePath
        Mandatory. Path of where log is to be created. Example: C:\Temp\

    .PARAMETER LogFileName
        Mandatory. Name of log file to be created. Ex: SampleScript.log

    .PARAMETER ScriptName
        Optional. Name of the running script, which will be used to identify the log file. Ex: PSAdvancedLogging.ps1

    .PARAMETER ScriptVersion
        Optional. Version of the running script which will be written in the log. Ex: 1.0

    .PARAMETER LogFormat
        Required. This defines the format by which logs will be outputted in. Options are JSON, Text, CSV, and CloudWatch JSON.

    .INPUTS
        Parameters above

    .OUTPUTS
        Log file created
    #>  

    Param
    (
        [Parameter(Mandatory=$true)]$LogFilePath,
        [Parameter(Mandatory=$true)]$LogFileName,
        [Parameter(Mandatory=$false)]$ScriptName,
        [Parameter(Mandatory=$false)]$ScriptVersion,
        [Parameter(Mandatory=$true)][ValidateSet("json","text","csv","cloudwatch","s3")]$LogFormat,
        [Parameter(Mandatory=$false)]$BucketName,
        [Parameter(Mandatory=$false)]$LogGroupName,
        [Parameter(Mandatory=$true)]$AWSRegion
    )
    $LogStartTimestamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
    if ( ( $LogFormat -eq "cloudwatch" ) -or ( $LogFormat -eq "s3" ) ){
        if ( ( $BucketName -eq "" ) -or ( $BucketName -eq $null )  -and ( $LogFormat -eq "s3" ) )
        {
            throw "If using S3, you must define a S3 bucket name"
            return $false
        }
        if ( ( $LogGroupName -eq "" ) -or  ( $LogGroupName -eq $null ) -and ( $LogFormat -eq "cloudwatch" ) )
        {
            throw "If using Cloudwatch, you must define the log group name."
            return $false
        }
        if ( ( $AWSRegion -eq "" ) -or ( $AWSRegion -eq $null )  -and ( $LogFormat -eq "s3" ) )
        {
            throw "If using S3, you must define a region."
            return $false
        }
        if ( Get-InstalledModule -Name "AWSPowershell" )
        {
            if ( !( Test-Path "$Env:USERPROFILE\.aws\credentials" ) )
            {
                Write-Host "To configure the module, run the 'Set-AWSCredential -AccessKey [accesskey] -SecretKey [secretkey] -StoreAs myProfile' command" -ForegroundColor Yellow
                throw "The AWSPowershell module does not have credentials configured." 
            }
        }
        else
        {
            Write-Host "Writing to CloudWatch or S3 requires the AWSPowershell module be installed." -ForegroundColor DarkRed
            Write-Host "Install-Module -Name AWSPowershell" -ForegroundColor DarkRed
            Write-Host "Once installed, run the 'Set-AWSCredential -AccessKey [accesskey] -SecretKey [secretkey] -StoreAs myProfile' command" -ForegroundColor DarkRed
            throw "The AWSPowershell module is not installed. Please install the module." 
        }
    }
    

    if( $LogFilePath -notmatch "\\$" ){ $LogFilePath = "$LogFilePath\\" }
    if( !( Test-Path $LogFilePath ) )
    {
        $User = [Security.Principal.WindowsIdentity]::GetCurrent()
        if( ( New-Object Security.Principal.WindowsPrincipal $User ).IsInRole( [Security.Principal.WindowsBuiltinRole]::Administrator ) )
        {
            mkdir $LogFilePath
            Write-Host "Created directory: $LogFilePath" -ForegroundColor DarkGreen
        }
        else
        {
            Write-Host "The log file path could not be found." -ForegroundColor DarkRed
            Write-Host "Unable to detect directory: $LogFilePath" -ForegroundColor DarkRed
            Write-Host "Since you're not running as admin, we couldn't create it for you." -ForegroundColor DarkRed
            Write-Host "Please run as administrator or create the directory yourself." -ForegroundColor DarkRed
        }
    }

    if ( $LogFormat -eq "cloudwatch" )
    {
        try
        {
            Write-CWLLogstream -LogGroupName $LogGroupName -LogStreamName $LogFileName -Region $AWSRegion
            Write-Host "Created log stream '$LogFileName' in log group $LogGroupName in region $AWSRegion" -ForegroundColor DarkGreen
            Add-LogFileContent -LogLevel "logstart" -LogMessage "We have began the logging for this script" -LogId "0" -EventId "0"
            Write-Host "Sucessfully wrote to the log group $LogGroupName under new stream $LogFileName"
        }
        catch
        {
            Write-Host "Failed to create a new cloudwatch log stream." -ForegroundColor DarkRed
        }
    }
    if( ( $LogFormat -eq "json" ) -or ( $LogFormat -eq "s3" ) )
    {
        $LogFileStart = @"
{
    "LogEntries": [
                
"@
    }
    elseif ( $LogFormat -eq "csv" )
    {
        $LogFileStart = "Timestamp,LogId,EventId,LogLevel,LogMessage,Script,ScriptVersion"
    }
    elseif ( $LogFormat -eq "text" )
    {
        $LogFileStart = @"
Writing logs TO $LogFilePath\$LogFileName...
Began logging at $LogStartTimestamp....
We are logging for $ScriptName $ScriptVersion
==============================================================================================================
===============Timestamp | LogId | EventId | LogLevel | LogMessage | ScriptName | ScriptVersion===============
==============================================================================================================
$LogStartTimestamp | 0 | 0 | LogStart | We starting logging to a raw text file | $ScriptName | $ScriptVersion
"@
    }

    Set-Item -Path Env:LogFilePath -Value $LogFilePath
    Set-Item -Path Env:LogFileName -Value $LogFileName
    Set-Item -Path Env:ScriptName -Value $ScriptName
    Set-Item -Path Env:ScriptVersion -Value $ScriptVersion
    Set-Item -Path Env:LogFormat -Value $LogFormat
    Set-Item -Path Env:AWSRegion -Value $AWSRegion
    if( $LogFormat -eq "cloudwatch" ){ Set-Item -Path Env:LogGroup -Value $LogGroupName }
    if( $LogFormat -eq "s3" ){ Set-Item -Path Env:BucketName -Value $BucketName }

    try
    {
        $LogFileStart | Out-File -FilePath "$LogFilePath$LogFileName"
        Write-Host "Started writing logs to $LogFilePath$LogFileName " -ForegroundColor DarkGreen
    }
    catch
    {
        Write-Host  "Unable to write to $LogFilePath$LogFileName. Check file name and permissions." -ForegroundColor DarkRed
    }
    if( $LogFormat -ne "text" )
    {
        Add-LogFileContent -LogMessage "Began the initial logging for $ScriptName $ScriptVersion in $LogFormat" -LogId "random" -LogLevel "logstart" -InformationAction SilentlyContinue
        Write-Host "Succesfully wrote the initial log entry." -ForegroundColor DarkGreen
    }
}

function  Add-LogFileContent
{
    <#
    .SYNOPSIS
        Appends data to an existing log file created by the "New-LogFile" command-let.

    .DESCRIPTION
        Appends data to a given log file. By default this will use the environmental variables
        set by New-LogFile cmdlet to define where, and how to write the logs. It uses the 
        $Env:LogFilePath, $Env:LogFileName, $Env:ScriptName, $End:ScriptVersion, and $Env:LogFormat
        environmental variables. This can be overriden with the Change-LogFile cmdlet.

    .PARAMETER LogMessage
        Mandatory. Content of the message you want to add to the log
    .PARAMETER LogId
        Optional. Numeric value or Unique ID for identifying the log. Defaults to randomized number.

    .PARAMETER EventId
        Optional. Use this to define the time of Event. If you're logging events where a specific action
        would trigger a specific log type, you can use this to identify it. Think of these as similar
        to Windows Event Log IDs. Defaults to "UNDEFINED"

    .PARAMETER LogLevel
        Mandatory. This defines the severity of the log. Must match on of the strings within the 
        validation set: "info","warning","error","critical","logstart","logend"

    .PARAMETER LastLog
        Optional. If this is set to true, we will close out the logs primarily for use with JSON
        formatted logs. 

    .INPUTS
        Parameters above

    .OUTPUTS
        Additional contents to a specified logfile.
    #>  

    param
    (
        [Parameter(Mandatory=$true)]$LogMessage,
        [Parameter(Mandatory=$false)]$LogId = (Get-Random),
        [Parameter(Mandatory=$false)]$EventId = "UNDEFINED",
        [Parameter(Mandatory=$true)][ValidateSet("info","warning","error","critical","logstart","logend")]$LogLevel,
        [Parameter(Mandatory=$false)]$LastLog = $false
    )
    $LogEntryTimestamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
    $LogFullPath = $Env:LogFilePath + $Env:LogFileName
    if( Test-path -Path $LogFullPath )
    {

        if(  ( $Env:LogFormat -eq "json" ) -or ( $Env:LogFormat -eq "s3" ) )
        {
            if( $LastLog -eq $false ) {
                $LogEntry = @"
        {
            "LogTimestamp" : "$LogEntryTimeStamp",
            "LogId" : "$LogId",
            "EventId" : "$EventId",
            "LogLevel" : "$LogLevel",
            "LogMessage": "$LogMessage",
            "ScriptName" : "$Env:ScriptName",
            "ScriptVersion" : "$Env:ScriptVersion"
        },
"@
            }
            else
            {
                $LogEntry = @"
        {
            "LogTimestamp" : "$LogEntryTimeStamp",
            "LogId" : "$LogId",
            "EventId" : "$EventId",
            "LogLevel" : "$LogLevel",
            "LogMessage": "$LogMessage",
            "ScriptName" : "$Env:ScriptName",
            "ScriptVersion" : "$Env:ScriptVersion"
        }
    ]    
}
"@
            }
        }
        elseif ( $Env:LogFormat -eq "csv" )
        {
            $LogEntry = "$LogEntryTimestamp,$LogId,$EventId,$Loglevel,$LogMessage,$Env:ScriptName,$Env:ScriptVersion"
        }
        else 
        {
            $LogEntry = "$LogStartTimestamp | $LogId | $EventId | $LogLevel | $LogMessage | $Env:ScriptName | $Env:ScriptVersion"
        }
      
    }
    try
    {
        Add-Content -Path $LogFullPath -Value $LogEntry
        if( ( $LastLog -eq $true ) -and ( ( $Env:LogFormat -eq "json" ) -or ( $Env:LogFormat -eq "s3" ) ) )
        {
            $IsValidJson = Test-JsonLogFile
            if( $IsValidJson )
            {
                Write-Host  "Wrote log entry to: $LogFullPath successfully and validated the JSON data." -ForegroundColor DarkGreen
            }
            else
            {
                WorkFolders.exe "Able to write the log entry to: $LogFullPath, but unable to validate the JSON data." -ForegroundColor Yellow    
            }
        }
        else
        {
            Write-Host  "Wrote log entry to: $LogFullPath successfully." -ForegroundColor DarkGreen
        }

    }
    catch
    {
        Write-Host "Unable to write log entry to: $LogFullPath - undefined error" -ForegroundColor DarkRed
        return $false
    }
    if( $Env:LogFormat -eq "cloudwatch" )
    {
        try
        {
            $CloudWatchEvent = New-Object -TypeName 'Amazon.CloudWatchLogs.Model.InputLogEvent'
            $CloudWatchEvent.Message = "Timestamp: $LogEntryTimestamp | LogId: $LogId | EventId: $EventId | LogLevel: $LogLevel | Message: $LogMessage | ScriptName: $Env:ScriptName | ScriptVersion: $Env:ScriptVersion"
            $CloudWatchEvent.Timestamp = (Get-Date).ToUniversalTime()
            $CloudWatchSplat = @{
                LogEvent      = $CloudWatchEvent
                LogGroupName  = $Env:LogGroupName
                LogStreamName = $Env:LogFileName
                Region = $Env:AWSRegion
            }
            Write-CWLLogEvent @CloudWatchSplat
            Write-Host "Succesfully wrote the log event to CloudWatch log group $Env:LogGroupName log stream $Env:LogFileName" -ForegroundColor DarkGreen
        }
        catch
        {
            Write-Host "Failed to write the event to log group $Env:LogGroupName log stream $Env:LogFileName" -ForegroundColor DarkRed
            Write-Host "Check credentials, log group name, and permissions." -ForegroundColor DarkRed
        }
    }
    if( ( $LastLog -eq $true ) -and ( $Env:LogFormat -eq "s3" ) )
    {
        try
        {
            Write-S3Object -BucketName $Env:BucketName -File $LogFullPath -Key "$Env:ScriptName/$Env:ScriptName-$LogEntryTimestamp.json" -Region $Env:AWSRegion
            Write-Host "Sucessfully wrote the logs to Amazon S3 Bucket: $Env:BucketName in region $Env:AWSRegion" -ForegroundColor DarkGreen
            Write-Host "Amazon S3 File:  s3://$Env:BucketName/$Env:ScriptName/$Env:ScriptName-$LogEntryTimestamp.json "
            return $true
        }
        catch
        {
            Write-Host  "Error writing to Amazon S3; please check bucket name, region, and credentials." -ForegroundColor DarkRed
            return $false
        }
        
    }
}

function Change-LogFile
{
    <#
    .SYNOPSIS
        Allows us to change the log file we are writing to.

    .DESCRIPTION
        Changes the environmental variables we defined so we can use a different log file without specifying
        in the parameters for the Add-LogFileContent cmdlet.

    .PARAMETER LogFilePath
        Mandatory. Path of the log file we're changing to

    .PARAMETER LogFileName
        Mandatory. Name of the log file we're going to change to.

    .PARAMETER ScriptName
        Optional. Name of the running script, which will be used to identify the log file. Ex: PSAdvancedLogging.ps1

    .PARAMETER ScriptVersion
        Optional. Version of the running script which will be written in the log. Ex: 1.0

    .PARAMETER LogFormat
        Required. This defines the format by which logs will be outputted in. Options are JSON, Text, CSV, and CloudWatch JSON.

    .INPUTS
        Parameters above

    .OUTPUTS
        Boolean, indicating whether we were able to successfully change the log file or not.
    #>  

    Param
    (
        [Parameter(Mandatory=$true)]$LogFilePath,
        [Parameter(Mandatory=$true)]$LogFileName,
        [Parameter(Mandatory=$false)]$ScriptName,
        [Parameter(Mandatory=$false)]$ScriptVersion,
        [Parameter(Mandatory=$true)][ValidateSet("json","text","csv","cloudwatch","s3")]$LogFormat,
        [Parameter(Mandatory=$false)]$BucketName,
        [Parameter(Mandatory=$false)]$LogGroupName,
        [Parameter(Mandatory=$false)]$AWSRegion
    )

    if( $LogFilePath -notmatch "\\$" ){ $LogFilePath = "$LogFilePath\\" }
    if( Test-Path "$LogFilePath$LogFileName")
    {
        if ( ( $Env:LogFormat -eq "json" )  -or ( $Env:LogFormat -eq "s3" ) -or ( $Env:LogFormat -eq "cloudwatch" ) ) 
        {
            $IsValidJson = Test-JsonLogFile -LogFileFullPath $LogFilePath$LogFileName -InformationAction SilentlyContinue
            if( $IsValidJson )
            {
                Write-Host "The given log file is already valid JSON, meaning that we cannot add members to the array." -ForegroundColor Yellow
                Write-Host "Please specify a JSON file without the closing brackets, or edit the current one and remove the last two lines" -ForegroundColor Yellow
                return $false
                throw "Failed to change the current logfile"
            }
            else
            {
                if( $LogFormat -eq "cloudwatch" ){ Set-Item -Path Env:LogGroup -Value $LogGroupName }
                if( $LogFormat -eq "s3" ){ Set-Item -Path Env:BucketName -Value $BucketName }
                if ( ( $AWSRegion -eq "" ) -or ( $AWSRegion -eq $null )  -and ( $LogFormat -eq "s3" ) )
                {
                    throw "If using S3, you must define a region."
                    return $false
                }
                else
                {
                    Set-Item -Path Env:AWSRegion $AWSRegion 
                }
            }
        }
        try
        {
            Set-Item -Path Env:LogFilePath -Value $LogFilePath
            Set-Item -Path Env:LogFileName -Value $LogFileName
            Set-Item -Path Env:ScriptName -Value $ScriptName
            Set-Item -Path Env:ScriptVersion -Value $ScriptVersion
            Set-Item -Path Env:LogFormat -Value $LogFormat
            Write-Host "Succesfully changed the log file context" -ForegroundColor DarkGreen
            return $true
        }
        catch
        {
            throw "Unable to change the log file context - unknown error"
            return $false
        }
    }
    else 
    {
        Write-Host "We couldn't find that file; unable to change the current log file context." -ForegroundColor DarkRed
        return $false
    }
}

function Test-JsonLogFile 
{   
    <#
    .SYNOPSIS
        Checks whether the given JSON log file is valid or not. 

    .DESCRIPTION
        Checks to see if we can convert our JSON Data to regular powershell hashtables - if it fails then this 
        assumes it is not valid JSON Data. If it doesn't fail, we assume valid JSON Data. Uses the default
        Environmental Variables

    .PARAMETER LogFileFullPath
        Optional. The full path of the log file to validate.

    .INPUTS
        Parameters above

    .OUTPUTS
        Boolean - indicating whether the log file is valid JSON or not.
    #>  

    Param
    (
        [Parameter(Mandatory=$false)]$LogFileFullPath
    )

    if( ( $LogFileFullPath -eq "" ) -or ( $LogFileFullPath -eq $null ) )
    {
        $LogFileFullPath = "$Env:LogFilePath$Env:LogFileName"
    }

    if ( ( $Env:LogFormat -ne "json" )  -and ( $Env:LogFormat -ne "s3" ) -and ( $Env:LogFormat -ne "cloudwatch" ) ) 
    {
        return $false
        throw "The current log file is not JSON. Please specify a new log file or use the Change-LogFile cmdlet."
    }

    try
    {
        $JsonData = Get-Content $LogFileFullPath | ConvertFrom-Json -ErrorAction Stop;
        $validJson = $true;
    }
    catch
    {
        $ValidJson = $false;
    }
    
    if ($validJson)
    {
        Write-Host "Provided file has been correctly parsed as JSON" -ForegroundColor DarkGreen
        return $true
    }
    else
    {
        Write-Host "Provided text is not a valid JSON string" -ForegroundColor DarkRed
        return $false
    }

}
