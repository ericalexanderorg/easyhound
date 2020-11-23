# EasyHound
EasyHound is a tool for resource constrained blue teams that don't have the time to setup and run [BloodHound](https://github.com/BloodHoundAD/BloodHound), or don't know how. It's intended for IT teams in small school districts or hospitals, the same ones getting hit hard by ransomware (commonly exploits this problem). 

## Running
* Clone this repo or [download a copy of the repo as a zip](https://github.com/ericalexanderorg/easyhound/archive/main.zip)
* Run .\easyhound.ps1 (in the Code directory)
* Wait for the output (can take an hour or more)
* Review the CSV in Code\cache\report.csv to find computers/servers where a domain admin is logged in and a non-admin can login and [become the domain admin](https://github.com/gentilkiwi/mimikatz)

## Goals
* All powershell. Reduce barriers to run.
* Easy and actionable insight for blue teams to address domain admin elevation vulnerabilities.

## Current State
* Powershell scripts that find computers/servers with domain admins logged in, and the opportunity for non-domain admins to login and dump their creds with [mimikatz](https://github.com/gentilkiwi/mimikatz).

## Desired State
* [Support deeper path insight](https://github.com/ericalexanderorg/easyhound/issues/1)
* [Get back to one script. Make it easier to run.](https://github.com/ericalexanderorg/easyhound/issues/2)
* [Improve speed](https://github.com/ericalexanderorg/easyhound/issues/3)
