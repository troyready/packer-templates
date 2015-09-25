$OS = Get-WmiObject -Class win32_OperatingSystem -namespace "root\CIMV2"

Enable-RemoteDesktop
if ($OS.Version -eq "6.1.7601") {
    C:\Windows\System32\netsh.exe advfirewall firewall add rule name="Remote Desktop" dir=in localport=3389 protocol=TCP action=allow
    } else {
    Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP -Enabled True
}

Write-BoxstarterMessage "Removing page file"
$pageFileMemoryKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-ItemProperty -Path $pageFileMemoryKey -Name PagingFiles -Value ""

Update-ExecutionPolicy -Policy Unrestricted

# cmdlet not available in win 7
if ($OS.Version -ne "6.1.7601") {
    Write-BoxstarterMessage "Removing unused features..."
    Remove-WindowsFeature -Name 'Powershell-ISE'
    Get-WindowsFeature | 
    ? { $_.InstallState -eq 'Available' } | 
    Uninstall-WindowsFeature -Remove
}

Install-WindowsUpdate -AcceptEula
if(Test-PendingReboot){ Invoke-Reboot }

Write-BoxstarterMessage "Cleaning SxS..."
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

@(
    "$env:localappdata\Nuget",
    "$env:localappdata\temp\*",
    "$env:windir\logs",
    "$env:windir\panther",
    "$env:windir\temp\*",
    "$env:windir\winsxs\manifestcache"
) | % {
        if(Test-Path $_) {
            Write-BoxstarterMessage "Removing $_"
            Takeown /d Y /R /f $_
            Icacls $_ /GRANT:r administrators:F /T /c /q  2>&1 | Out-Null
            Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

Write-BoxstarterMessage "defragging..."
if ($OS.Version -eq "6.1.7601") {
    Defrag.exe c: /H
    } else {
    Optimize-Volume -DriveLetter C
}


Write-BoxstarterMessage "0ing out empty space..."
wget http://download.sysinternals.com/files/SDelete.zip -OutFile sdelete.zip
[System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem")
[System.IO.Compression.ZipFile]::ExtractToDirectory("sdelete.zip", ".") 
./sdelete.exe /accepteula -z c:

mkdir C:\Windows\Panther\Unattend
if ($OS.Version -eq "6.1.7601") {
    copy-item a:\postunattendwin7.xml C:\Windows\Panther\Unattend\unattend.xml
    } else {
    copy-item a:\postunattend.xml C:\Windows\Panther\Unattend\unattend.xml
}

Write-BoxstarterMessage "Recreate pagefile after sysprep"
$System = GWMI Win32_ComputerSystem -EnableAllPrivileges
$System.AutomaticManagedPagefile = $true
$System.Put()

Write-BoxstarterMessage "Setting up winrm"
if ($OS.Version -eq "6.1.7601") {
    C:\Windows\System32\netsh.exe advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow
    } else {
    Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any
}

if ($OS.Version -eq "6.1.7601") {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Enable-WSManCredSSP -Force -Role Server
    } else {
    Enable-WSManCredSSP -Force -Role Server

    Enable-PSRemoting -Force -SkipNetworkProfileCheck
}
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
