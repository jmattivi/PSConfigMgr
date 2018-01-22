workflow Invoke-ConfigMgrSoftwareUpdates
{
    <#	
    .NOTES
    	AUTHOR: 	Jon Mattivi
    	COMPANY: 
    	CREATED DATE: 2014-10-15
    	SCRIPT LANGUAGE: PowerShell

    .SYNOPSIS
    	Remotely installs software updates throught the ConfigMgr WMI namespace

    .PARAMETER ServerName
    	Run against single server

    .PARAMETER InputFilePath
    	Run against multiple servers specified

    .PARAMETER SuppressReboot
    	Prevent reboots from occuring pre or post update install

    .PARAMETER Reboot
    	Reboot the server(s).  No update install is attempted.

    .EXAMPLE
    	Invoke-ConfigMgrSoftwareUpdates -ServerName myserver

    .EXAMPLE
    	Invoke-ConfigMgrSoftwareUpdates -ServerName myserver -Verbose

    .EXAMPLE
    	Invoke-ConfigMgrSoftwareUpdates -ServerName myserver -Reboot -Verbose

    .EXAMPLE
    	Invoke-ConfigMgrSoftwareUpdates -ServerName myserver -SuppressReboot -Verbose

    .EXAMPLE
        Invoke-ConfigMgrSoftwareUpdates -InputFilePath "C:\Users\jcmattivi\Desktop\ConfigMgr-SU-HostNames.txt" -Verbose
    
    .LINK
        Get-RebootRequired
    
    .LINK
        Start-OpsMgrMaintenanceMode

    #>

    Param (
        [parameter(mandatory = $false)]
        [String]$InputFilePath,
        [parameter(mandatory = $false)]
        [String]$ServerName,
        [parameter(mandatory = $false)]
        [Switch]$SuppressReboot,
        [parameter(mandatory = $false)]
        [Switch]$Reboot
    )
	
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	
    If ($InputFilePath)
    {
        $Servers = Get-Content -Path $InputFilePath
    }
    Elseif ($ServerName)
    {
        $Servers = $ServerName
    }
	

    ####Begin Processing####
    ForEach -parallel -ThrottleLimit 50 ($Server in $Servers)
    {
        $StartTime = Get-Date
        If (Test-Connection -ComputerName $Server -Count 1)
        {
            Write-Verbose "INFO   `t$Server - is online"
            #Check if Reboot switch was used
            If ($Reboot)
            {
                InlineScript
                {
                    $SaveVerbosePreference = $global:VerbosePreference
                    $global:VerbosePreference = 'SilentlyContinue'
                    . "$using:PSWorkflowRoot\Private\Start-OpsMgrMaintenanceMode.ps1"
                    Import-Module "$using:PSWorkflowRoot\Private\OperationsManager\PowerShell\OperationsManager\OperationsManager.psd1"
                    $global:VerbosePreference = $SaveVerbosePreference
                                
                    Start-OpsMgrMaintenanceMode -ServerName $using:Server -Minutes 15
                }
				
                Write-Verbose "INFO   `t$Server - The reboot switch was specified.  A reboot will now occur."
                Restart-Computer -PSComputerName $Server -Wait -For Wmi -Timeout 600 -Force
                Write-Output "SUCCESS   `t$Server - Successfully rebooted"
            }
            else
            {
                #Check if there is a pending reboot already otherwise first reboot.
                $RebootRequired = Get-RebootRequired -ServerName $Server
                If ($RebootRequired -eq $true)
                {
                    If ($SuppressReboot)
                    {
                        Write-Output "ERROR   `t$Server - A pending reboot is required prior to installing updates.  However, all reboots were suppressed."
                        exit
                    }
                    Else
                    {
                        InlineScript
                        {
                            $SaveVerbosePreference = $global:VerbosePreference
                            $global:VerbosePreference = 'SilentlyContinue'
                            . "$using:PSWorkflowRoot\Private\Start-OpsMgrMaintenanceMode.ps1"
                            Import-Module "$using:PSWorkflowRoot\Private\OperationsManager\PowerShell\OperationsManager\OperationsManager.psd1"
                            $global:VerbosePreference = $SaveVerbosePreference
                                
                            Start-OpsMgrMaintenanceMode -ServerName $using:Server -Minutes 15
                        }
						
                        Write-Verbose "INFO   `t$Server - There is a pending reboot for the system.  A reboot will occur prior to installing updates."
                        Restart-Computer -PSComputerName $Server -Wait -For Wmi -Timeout 600 -Force
                        Start-Sleep 150
                    }
                }

                #Trigger SCCM Update Scan and wait a little
                InlineScript
                {
                    Invoke-WmiMethod -ComputerName $using:Server -Namespace root\ccm -Class SMS_Client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000113}' | Out-Null
                    $waitingseconds = 30
                    Write-Verbose "INFO   `t$using:Server - The SCCM Update Scan has been triggered. The script is suspended for $(1*$waitingseconds) seconds to let the update scan finish."
                    Start-Sleep -Seconds $(1 * $waitingseconds)
					
                    #Trigger SCCM Update Deployment Evailuation and wait a little
                    Invoke-WmiMethod -ComputerName $using:Server -Namespace root\ccm -Class SMS_Client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000108}' | Out-Null
                    $waitingseconds = 60
                    Write-Verbose "INFO   `t$using:Server - The SCCM Update Deployment Evaluation has been triggered. The script is suspended for $(1*$waitingseconds) seconds to let the update deployment evaluation finish."
                    Start-Sleep -Seconds $(1 * $waitingseconds)
                }
				
                #Check the number of missing updates
                [System.Management.ManagementObject[]]$CMMissingUpdates = @(Get-WmiObject -ComputerName $Server -Query "SELECT * FROM CCM_SoftwareUpdate WHERE ComplianceState = '0'" -Namespace "ROOT\ccm\ClientSDK")
                If ($CMMissingUpdates.count)
                {
                    Write-Verbose "INFO   `t$Server - The number of missing updates is $($CMMissingUpdates.count)"
                    $CMInstallMissingUpdates = (Get-WmiObject -ComputerName $Server -Namespace 'root\ccm\clientsdk' -Class 'CCM_SoftwareUpdatesManager' -List).InstallUpdates([System.Management.ManagementObject[]]$CMMissingUpdates)

                    InlineScript
                    {
                        Do
                        {
                            $waitingseconds = 15
                            Start-Sleep $(2 * $waitingseconds)
                            [array]$CMInstallPendingUpdates = @(Get-WmiObject -ComputerName $using:Server -Query "SELECT * FROM CCM_SoftwareUpdate WHERE EvaluationState != 8 and EvaluationState != 13" -Namespace "ROOT\ccm\ClientSDK")
                            Write-Verbose "INFO   `t$using:Server - The number of pending updates for installation is $($CMInstallPendingUpdates.count)"
                        } 
                        While (($CMInstallPendingUpdates.count -ne 0) -and ((New-TimeSpan -Start $using:StartTime -End $(Get-Date)) -lt "01:00:00"))
                    }
                    #Check for Pending Reboot
                    Start-Sleep 10
                    $RebootRequired = Get-RebootRequired -ServerName $Server
                    If ($RebootRequired -eq $true)
                    {
                        If ($SuppressReboot)
                        {
                            Write-Output "STATUS   `t$Server - A reboot is required to complete installing updates.  However, all reboots were suppressed."
                        }
                        Else
                        {
                            InlineScript
                            {
                                $SaveVerbosePreference = $global:VerbosePreference
                                $global:VerbosePreference = 'SilentlyContinue'
                                . "$using:PSWorkflowRoot\Private\Start-OpsMgrMaintenanceMode.ps1"
                                Import-Module "$using:PSWorkflowRoot\Private\OperationsManager\PowerShell\OperationsManager\OperationsManager.psd1"
                                $global:VerbosePreference = $SaveVerbosePreference

                                Start-OpsMgrMaintenanceMode -ServerName $using:Server -Minutes 15
                            }
							
                            Restart-Computer -PSComputerName $Server -Wait -For Wmi -Timeout 600 -Force
                            Start-Sleep 150
                            Write-Output "SUCCESS   `t$Server - Software Updates Installed Successfully and rebooted"
                        }
                    }
                    ElseIf ($RebootRequired -eq $false)
                    {
                        Write-Output "SUCCESS   `t$Server - Software Updates Installed Successfully and no reboot required"
                    }
                }
                Else
                {
                    Write-Output "SUCCESS   `t$Server - There are no missing updates"
                }
            }
        }
        Else
        {
            Write-Output "ERROR   `t$Server - is unavailable!!!!"
        }
		
    }
}