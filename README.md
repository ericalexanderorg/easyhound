# easyhound
Easy alternative to Blood Hound

## Running
* Clone this repo or download a copy of the repo as a zip
* Run easyhound.ps1: .\easyhound.ps1
* Wait for the output (can take an hour or more)
* Review the CSV in cache\report.csv to find computers/servers where a domain admin is logged in and a non-admin can login and [become the domain admin](https://github.com/gentilkiwi/mimikatz)

## Why
[BloodHound](https://github.com/BloodHoundAD/BloodHound) is a tool to find a path to elevate from Domain User to Domain Admin in an Active Directory domain.

This isn't a replacement for BloodHound, it's a simple alternative with barriers removed to provide a glimpse into the problem. 

## Goals
* All powershell. Reduce barriers to run.
* Support finding shortest path to admin.

## Current State
* Powershell scripts that find computers/servers with domain admins logged in, and the opportunity for non-domain admins to login and dump their creds with [mimikatz](https://github.com/gentilkiwi/mimikatz).

## Desired State
* Support deeper path insight, beyond single node insight. 