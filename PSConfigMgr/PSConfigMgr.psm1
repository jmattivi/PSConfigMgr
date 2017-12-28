#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source files that are nested
Try
{
    . $PSScriptRoot\Private\Get-RebootRequired.ps1
    . $PSScriptRoot\Private\Start-OpsMgrMaintenanceMode.ps1
    . $PSScriptRoot\Private\Invoke-ConfigMgrSoftwareUpdates.ps1
    #. $PSScriptRoot\Private\OperationsManager\PowerShell\OperationsManager\OperationsManager.psd1
}
Catch
{
    Write-Error -Message "Failed to import function: $_"
}

#Dot source the files
Foreach ($import in @($Public + $Private))
{
    Try
    {
        . $import.fullname
        Write-Output $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

#Read in or create an initial config file and variable

#Export Public functions ($Public.BaseName) for WIP modules
Export-ModuleMember -Function $Public.Basename

#Set variables visible to the module and its functions only