Function Get-RebootRequired
{
    <#	
    .NOTES
    	AUTHOR: 	Jon Mattivi
    	COMPANY: 
    	CREATED DATE: 2014-10-15
    	SCRIPT LANGUAGE: PowerShell

    .SYNOPSIS
    	Returns True or False if the computer is currently pending a reboot

    .PARAMETER ServerName
    	Run against single server

    .EXAMPLE
        Get-RebootRequired -ServerName myserver
    
    .LINK
        http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542/view/Discussions#content

    #>
    Param (
        [parameter(mandatory = $true)]
        [String]$ServerName
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    $result = @{
        CBSRebootPending            = $false
        WindowsUpdateRebootRequired = $false
        FileRenamePending           = $false
        SCCMRebootPending           = $false
    }

    #Start Remote Registry If Not Started
    If ((Get-Service -Name RemoteRegistry -ComputerName $ServerName).Status -ne "Running")
    {
        Write-Verbose "INFO   `t$ServerName - RemoteRegistry service is not running.  Attempting to start...."
        Get-Service -Name RemoteRegistry -ComputerName $ServerName | Start-Service
        Write-Verbose "INFO   `t$ServerName - RemoteRegistry service has been started"
    }

    #Open Remote Registry
    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ServerName)

    #Check CBS Registry
    $OS = Get-WmiObject -Computer $ServerName -Class Win32_OperatingSystem
    If ($OS.Version -notlike "5.*")
    {
        $CBSRegKey = $Reg.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing")
        $CBSValue = $CBSRegKey.GetValue("RebootPending")
        if ($CBSValue -ne $null)
        {
            $result.CBSRebootPending = $true
        }
    }

    #Check Windows Update
    $WURegKey = $Reg.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update")
    $WUValue = $WURegKey.GetValue("RebootRequired")
    if ($WUValue -ne $null)
    {
        $result.WindowsUpdateRebootRequired = $true
    }

    #Check SCCM Client
    $CCMRebootPending = (Invoke-WmiMethod -ComputerName $ServerName -Namespace root\ccm\clientsdk -Class CCM_ClientUtilities -Name DetermineIfRebootPending).RebootPending
    if (($CCMRebootPending -ne $false))
    {
        $result.SCCMRebootPending = $true
    }

    #Return Reboot Required
    return $result.ContainsValue($true)
}