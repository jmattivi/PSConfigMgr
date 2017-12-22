Function Install-ConfigMgrSoftwareUpdates
{
    <#	
    .NOTES
    	AUTHOR: 	Jon Mattivi
    	COMPANY: 
    	CREATED DATE: 2014-10-15
    	SCRIPT LANGUAGE: PowerShell

        KNOWN ISSUES: Will not work on Server 2003

    .SYNOPSIS
    	Remotely installs software updates throught the ConfigMgr WMI namespace

    .PARAMETER ServerName
    	Run against single server

    .PARAMETER InputFilePath
    	Run against multiple servers specified

    .PARAMETER SuppressReboot
    	Prevent reboots from occuring pre or post update install

    .PARAMETER Reboot
        Reboot the server(s).  No update install is attempted
    
    .PARAMETER Schedule
    	Specifies the invocation should start at a scheduled time in the future

    .EXAMPLE
    	Install-ConfigMgrSoftwareUpdates -ServerName myserver

    .EXAMPLE
    	Install-ConfigMgrSoftwareUpdates -ServerName myserver -Verbose

    .EXAMPLE
    	Install-ConfigMgrSoftwareUpdates -ServerName myserver -Reboot -Verbose

    .EXAMPLE
    	Install-ConfigMgrSoftwareUpdates -ServerName myserver -SuppressReboot -Verbose

    .EXAMPLE
        Install-ConfigMgrSoftwareUpdates -InputFilePath "C:\Users\jcmattivi\Desktop\ConfigMgr-SU-HostNames.txt" -Verbose
    
    .EXAMPLE
        Install-ConfigMgrSoftwareUpdates -ServerName myserver -Schedule -StartYear 2017 -StartMonth 12 -StartDay 19 -StartHour 14 -StartMinute 30 -Verbose
    
    #>

    [CmdletBinding(DefaultParametersetName = 'MyParamSet')]
    Param (
        [parameter(position = 0, mandatory = $false)]
        [String]$InputFilePath,
        [parameter(position = 1, mandatory = $false)]
        [String]$ServerName,
        [parameter(position = 2, mandatory = $false)]
        [Switch]$SuppressReboot,
        [parameter(position = 3, mandatory = $false)]
        [Switch]$Reboot,
        [parameter(position = 4, ParameterSetName = 'EnableSchedule')]
        [Switch]$Schedule,
        [Parameter(mandatory = $true, ParameterSetName = 'EnableSchedule')]
        [int]$StartYear,
        [Parameter(mandatory = $true, ParameterSetName = 'EnableSchedule')]
        [int]$StartMonth,
        [Parameter(mandatory = $true, ParameterSetName = 'EnableSchedule')]
        [int]$StartDay,
        [Parameter(mandatory = $true, ParameterSetName = 'EnableSchedule')]
        [int]$StartHour,
        [Parameter(mandatory = $true, ParameterSetName = 'EnableSchedule')]
        [int]$StartMinute
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue
    #Confirm Input Parameters
    If (!($InputFilePath) -and !($ServerName))
    {
        throw "You must supply a list file path or server name!"
        exit
    }
    If (($InputFilePath) -and ($ServerName))
    {
        throw "You must supply either a list file path or server name, not both!"
        exit
    }
    elseif ($InputFilePath)
    {
        $Servers = Get-Content -Path $InputFilePath
    }
    elseif ($ServerName)
    {
        $Servers = $ServerName
    }
    If (($Reboot) -and ($SuppressReboot))
    {
        throw "You cannot use the Reboot and SuppressReboot switches at the same time!"
        exit
    }
	
    If ($Reboot)
    {
        $Caption = "Confirm Action";
        $Message = "Do you want to reboot the system(s)?";
        $Restart = New-Object System.Management.Automation.Host.ChoiceDescription "&Restart", "Restart";
        $NoRestart = New-Object System.Management.Automation.Host.ChoiceDescription "&NoRestart", "Exit (No Restart)";
        $Choices = [System.Management.Automation.Host.ChoiceDescription[]]($Restart, $NoRestart);
        $Answer = $host.ui.PromptForChoice($Caption, $Message, $Choices, 1)

        switch ($Answer)
        {
            0
            {
                "You entered restart"
            }
            1
            {
                "You entered exit (no restart)"
            }
        }
		
        If ($Answer -eq 1)
        {
            Write-Output "Processing aborted....Goodbye."
            return
        }
    }
		
    #Configure Logging
    $FolderNameDate = Get-Date -Format yyyyMMdd
    $FileNameDate = Get-Date -Format yyyyMMdd_HH-mm-ss-fff
    $CurrentUser = [Environment]::UserName
    $TranscriptDir = "$Env:TEMP\$FolderNameDate\$CurrentUser\"
    $TranscriptFile = $TranscriptDir + $FileNameDate + ".log"
    If (!(Test-Path -Path $TranscriptDir))
    {
        New-Item -ItemType Directory -Path $TranscriptDir | Out-Null
    }
    Start-Transcript -Path $TranscriptFile | Out-Null
    "Parameters Specified"
    "InputFile:			$InputFilePath"
    "Server Name:		$ServerName"
    "Suppress Reboot:	$SuppressReboot"
    "Reboot:			$Reboot"
    "Schedule:			$Schedule"
	
    If ($Schedule)
    {
        [DateTime]$CurrentTime = Get-Date
        $StartTime = get-date -Year $StartYear -Month $StartMonth -Day $StartDay -Hour $StartHour -Minute $StartMinute
        $SleepDiff = $StartTime - $CurrentTime
        $Sleep = $SleepDiff.TotalSeconds

        If ($Sleep -ge 0)
        {
            Write-Verbose "INFO   `tWaiting $Sleep seconds to begin at $StartTime"
            Sleep -Seconds $Sleep
        }
        Else
        {
            throw "You cannot schedule a time in the past!"
            exit
        }
    }
		
    $LimitedParameters = $PSBoundParameters
    $LimitedParameters.Remove("Schedule") | Out-Null
    $LimitedParameters.Remove("StartYear") | Out-Null
    $LimitedParameters.Remove("StartMonth") | Out-Null
    $LimitedParameters.Remove("StartDay") | Out-Null
    $LimitedParameters.Remove("StartHour") | Out-Null
    $LimitedParameters.Remove("StartMinute") | Out-Null
		
    Invoke-ConfigMgrSoftwareUpdates @LimitedParameters
		
    Stop-Transcript | Out-Null
}