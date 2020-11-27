# EasyHound
EasyHound is a tool for resource constrained blue teams that don't have the time to setup and run [BloodHound](https://github.com/BloodHoundAD/BloodHound), or don't know how. It's intended for IT teams in small school districts or hospitals, the same ones getting hit hard by ransomware (commonly exploits this problem). 

## Running
* From powershell install AD Tools if you don't already have installed: Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
* Inspect if you'd like: https://raw.githubusercontent.com/ericalexanderorg/easyhound/main/Code/easyhound.ps1
* Run the following in powershell: iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/ericalexanderorg/easyhound/main/Code/easyhound.ps1'))

## Goals
* All powershell. Reduce barriers to run.
* Easy and actionable insight for blue teams to address domain admin elevation vulnerabilities.

## Current State
* Powershell scripts that find computers/servers with domain admins logged in, and the opportunity for non-domain admins to login and dump their creds with [mimikatz](https://github.com/gentilkiwi/mimikatz).

## Desired State
* [Support deeper path insight](https://github.com/ericalexanderorg/easyhound/issues/1)
* [Get back to one script. Make it easier to run.](https://github.com/ericalexanderorg/easyhound/issues/2)
* [Improve speed](https://github.com/ericalexanderorg/easyhound/issues/3)
