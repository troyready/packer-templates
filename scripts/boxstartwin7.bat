@ECHO OFF
if exist c:\ProgramData\chocolatey\bin (
    rem no-op indefinitely
) else (
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -File a:\boxstarter.ps1
  )
