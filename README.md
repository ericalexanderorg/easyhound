# EasyHound
EasyHound is a tool for resource constrained blue teams that don't have the time to setup and run [BloodHound](https://github.com/BloodHoundAD/BloodHound), or don't know how. It's intended for IT teams in small school districts or hospitals, the same ones getting hit hard by ransomware (commonly exploits this problem). 

## Running
In a powershell console:


    # Install AD Tools if not already installed
    Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
    # Download and run EasyHound (inspect first if you'd like)
    $CWD = Get-Location
    $client = new-object System.Net.WebClient
    $client.DownloadFile("https://raw.githubusercontent.com/ericalexanderorg/easyhound/main/Code/easyhound.ps1", "$CWD\easyhound.ps1")
    ./easyhound.ps1`

## Goals
* All powershell. Reduce barriers to run.
* Easy and actionable insight for blue teams to address domain admin elevation vulnerabilities.

## Current State
* Powershell scripts that find computers/servers with domain admins logged in (opportunity for non-domain admins to login and dump their creds with [mimikatz](https://github.com/gentilkiwi/mimikatz)).

## Desired State
* [Support deeper path insight](https://github.com/ericalexanderorg/easyhound/issues/1)

