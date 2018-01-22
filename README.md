PSConfigMgr allows you to install or uninstall deployed applications and/or updates from ConfigMgr.

The Operations Manager module is also included for submitting agents for maintenance mode.
    ****There is a requirement to hardcode your OpsMgr management server or VIP in the following line.
        New-SCOMManagementGroupConnection -ComputerName <updateservername>
