Function Start-OpsMgrMaintenanceMode
{
    <#	
    .NOTES
    	AUTHOR: 	Jon Mattivi
    	COMPANY: 
    	CREATED DATE: 2014-10-15
    	SCRIPT LANGUAGE: PowerShell

    .SYNOPSIS
        Submits the OpsMgr agent for maintenance mode
    
    .DESCRIPTION
        Assumes OpsMgr management servers and gateway servers have the following naming conventions - scomms/dmzscomgw.  This prevents them from being put into maintenance mode

    .PARAMETER ServerName
        Run against single server
    
    .PARAMETER Minutes
    	Specify length of maintenance window (Must be greater than or equal to 5)

    .EXAMPLE
        Start-OpsMgrMaintenanceMode -MgmtServerName mymgmtserver -ServerName myserver -Minutes 30
    
    #>

    Param (
        [parameter(mandatory = $true)]    
        [String]$MgmtServerName,    
        [parameter(mandatory = $true)]
        [String]$ServerName,
        [parameter(mandatory = $true)]
        [String]$Minutes
    )
	
    Write-Verbose "STATUS   `t$ServerName - Submitting for Maintenance Mode"
    $SaveVerbosePreference = $global:VerbosePreference
    $global:VerbosePreference = 'SilentlyContinue'
	
    New-SCOMManagementGroupConnection -ComputerName MgmtServerName
    $global:VerbosePreference = $SaveVerbosePreference
	
    $SaveErrorActionPreference = $global:ErrorActionPreference
    $global:ErrorActionPreference = 'SilentlyContinue'

    $MMEndTime = (Get-Date).AddMinutes($Minutes)
    $ClassType = Get-ScomClass -Name Microsoft.Windows.Computer
    $Instance = Get-SCOMClassInstance -Class $ClassType  | ? {$_.DisplayName -like "$ServerName*"}
	
    If (($ServerName -notlike "*scomms*") -and ($ServerName -notlike "dmzscomgw*"))
    {
        If ($Instance)
        {
            If (Get-SCOMMaintenanceMode -Instance $Instance)
            {
                Write-Verbose "STATUS   `t$ServerName - Already in Maintenance Mode"
            }
            Else
            {
                Start-SCOMMaintenanceMode -Instance $Instance -EndTime $MMEndTime -Comment "Patching" -Reason PlannedOther
		
                If (Get-SCOMMaintenanceMode -Instance $Instance)
                {
                    Write-Verbose "SUCCESS   `t$ServerName - Maintenance Mode started"
                }
                Else
                {
                    Write-Output "ERROR   `t$ServerName - Maintenance Mode failed!!!!"
                }
                Sleep 30
            }
        }
        Else
        {
            Write-Output "ERROR   `t$ServerName - Agent not found!!!!"
        }
    }
	
    $global:ErrorActionPreference = $SaveErrorActionPreference
}