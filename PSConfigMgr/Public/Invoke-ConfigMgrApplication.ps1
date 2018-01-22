Function Invoke-ConfigMgrApplication
{
    <#
    .SYNOPSIS
       Invoke installation or uninstallation of available application on remote computer

    .DESCRIPTION
      Function that will invoke an Installation or Uninstallation of specified Application in Software Center that's available for the remote computer.

    .PARAMETER Computername
        Specify the remote computer you wan't to run the script against

    .PARAMETER AppName
        Specify the Application you wan't to invoke an action on

    .PARAMETER Method
        Specify the method or action you want to perform, Install or Uninstall

    .EXAMPLE
        Invoke-ConfigMgrApplication -Computername myserver -AppName "Google Chrome" -Method Install

    .EXAMPLE
        Invoke-ConfigMgrApplication -Computername myserver -AppName "Google Chrome" -Method Uninstall
    
    .EXAMPLE
        Invoke-ConfigMgrApplication -Computername myserver -Method List

    .NOTES  
             
    #>
    [CmdletBinding()]
    Param
    (
        [String][Parameter(Mandatory = $True, Position = 1)]
        $Computername,
        [String][Parameter(Mandatory = $False, Position = 2)]
        $AppName,
        [ValidateSet("List", "Install", "Uninstall")]
        [String][Parameter(Mandatory = $True, Position = 3)]
        $Method
    )
	
    if ($Method -eq "List")
    {
        $AvailableApplications = (Get-CimInstance -ClassName CCM_Application -Namespace "root\ccm\clientSDK" -ComputerName $Computername).Name
        Write-Output $AvailableApplications
    }
    elseif ($Method -eq "Status")
    {
        $EvalStateDefs = @{ 
            0  = 'No state information is available'; 
            1  = 'Application is enforced to desired/resolved state'; 
            2  = 'Application is not required on the client'; 
            3  = 'Application is available for enforcement (install or uninstall based on resolved state). Content may/may not have been downloaded'; 
            4  = 'Application last failed to enforce (install/uninstall)'; 
            5  = 'Application is currently waiting for content download to complete'; 
            6  = 'Application is currently waiting for content download to complete'; 
            7  = 'Application is currently waiting for its dependencies to download'; 
            8  = 'Application is currently waiting for a service (maintenance) window'; 
            9  = 'Application is currently waiting for a previously pending reboot'; 
            10 = 'Application is currently waiting for serialized enforcement'; 
            11 = 'Application is currently enforcing dependencies'; 
            12 = 'Application is currently enforcing'; 
            13 = 'Application install/uninstall enforced and soft reboot is pending'; 
            14 = 'Application installed/uninstalled and hard reboot is pending'; 
            15 = 'Update is available but pending installation'; 
            16 = 'Application failed to evaluate'; 
            17 = 'Application is currently waiting for an active user session to enforce'; 
            18 = 'Application is currently waiting for all users to logoff'; 
            19 = 'Application is currently waiting for a user logon'; 
            20 = 'Application in progress, waiting for retry'; 
            21 = 'Application is waiting for presentation mode to be switched off'; 
            22 = 'Application is pre-downloading content (downloading outside of install job)'; 
            23 = 'Application is pre-downloading dependent content (downloading outside of install job)'; 
            24 = 'Application download failed (downloading during install job)'; 
            25 = 'Application pre-downloading failed (downloading outside of install job)'; 
            26 = 'Download success (downloading during install job)'; 
            27 = 'Post-enforce evaluation'; 
            28 = 'Waiting for network connectivity'; 
        }

        $Application = (Get-CimInstance -ClassName CCM_Application -Namespace "root\ccm\clientSDK" -ComputerName $Computername | Where-Object { $_.Name -like $AppName })
        $objstate = New-Object System.Management.Automation.PSObject -Property ([Ordered]@{
                InstallState = $Application.InstallState
                EvalState    = $EvalStateDefs[[int]($Application.EvaluationState)]
            })
        
        Write-Output $objstate
    }
    else
    {
        $Application = (Get-CimInstance -ClassName CCM_Application -Namespace "root\ccm\clientSDK" -ComputerName $Computername | Where-Object { $_.Name -like $AppName })
		
        $Args = @{
            EnforcePreference = [UINT32] 0
            Id                = "$($Application.id)"
            IsMachineTarget   = $Application.IsMachineTarget
            IsRebootIfNeeded  = $False
            Priority          = 'High'
            Revision          = "$($Application.Revision)"
        }
		
        Invoke-CimMethod -Namespace "root\ccm\clientSDK" -ClassName CCM_Application -ComputerName $Computername -MethodName $Method -Arguments $Args
    }
}