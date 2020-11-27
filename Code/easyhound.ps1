param
(
    [bool]$ReportOnly = $false,
    [bool]$GetNodeData = $false,
    [bool]$CheckNodeAlive = $false,
    [string]$CWD,
    [string]$NodeName,
    [string]$DomainName
)

function Get-Nodes() {
    $CWD = Get-Location
    $DomainName = (Get-ADDomain).NetBIOSName
    Debug("Pulling list of nodes from Active Directory")
    try {
        $Nodes = Get-ADComputer -Filter * 
    }
    catch {
        Debug "Error pulling nodes from AD. Exiting!"
        Exit 1
    }

    $i = 0
    $NodesCount = $Nodes.count
    $Nodes | ForEach-Object {
        $NodeName = $_.DNSHostName
        Debug("Processing $NodeName")
        # Start jobs until we hit 75% CPU usage
        While ((Get-WmiObject Win32_processor).LoadPercentage -ge 75){
            Start-Sleep -Milliseconds 1000
        }
        $Process = Start-Process powershell.exe -ArgumentList "$CWD\easyhound.ps1 -GetNodeData 1 -NodeName $NodeName -CWD $CWD -DomainName $DomainName" -NoNewWindow -Passthru
        $i++
        Write-Progress -Id 1 -Activity 'Processing nodes' -Status "$i of $NodesCount nodes processed" -PercentComplete ($i / $NodesCount * 100)
    }
}


function Get-Node-Data{
    param(
        [string]$NodeName,
        [string]$DomainName,
        [string]$CWD
    )

    $Script = {
        param(
            [string]$NodeName,
            [string]$DomainName,
            [string]$CWD
        )

        # Create object
        $Node = new-object psobject
        # Add name
        $Node | Add-Member -NotePropertyName "name" -NotePropertyValue $NodeName
        # Add sessions
        $UserNames = (Get-Process -IncludeUserName | Select-Object UserName -Unique).UserName
        $DomainUserNames = @()
        foreach($UserName in $UserNames){
            # Domain user?
            if ($UserName -match "^$DomainName"){
                $DomainUserNames += $UserName
            }
        }
        $Node | Add-Member -NotePropertyName "sessions" -NotePropertyValue $DomainUserNames
        # Add admins
        $Principals = Get-LocalGroupMember Administrators
        $DomainPrincipals = @()
        foreach($Principal in $Principals){
            if ($Principal.Name -match "^$DomainName"){
                $DomainPrincipals += $Principal.Name
            }  
        }
        $Node | Add-Member -NotePropertyName "admins" -NotePropertyValue $DomainPrincipals
        # Return json doc
        return $Node | ConvertTo-Json
    }

    $Node = Invoke-Command -ScriptBlock $Script -ArgumentList $NodeName,$DomainName,$CWD -ComputerName $NodeName
    # Cache it
    $Node | Set-Content -Path "$CWD\cache\nodes\$NodeName"
}

function Get-Domain-Group-Members($Name){
    # Create the cached object if it doesn't exist
    Cache-Generic -Path ".\cache\groups\$Name"

    # Read the cached object
    $Path = ".\cache\groups\$Name"
    $Group = Get-Content $Path | ConvertFrom-Json
    $GroupName = $Group.name

    # Hack for bug
    if ($GroupName -eq "System.DirectoryServices.DirectoryEntry"){
        return
    }

    # Create the members property if it does not exist
    if (-not ("members" -in $Group.PSobject.Properties.Name)){
        $Members = @()
        $Group | Add-Member -NotePropertyName "members" -NotePropertyValue $Members
    }

    Get-ADGroupMember -Identity "$GroupName" -Recursive | ForEach-Object {
        $UserName = $_.SamAccountName
        $UserPath = ".\cache\users\$UserName"
        if (-not ($Group.members -contains $UserPath)){
            $Group.members += $UserPath
        }
    }

    # Save the object changes
    $Group | ConvertTo-Json | Set-Content -Path $Path
}

function Generate-Report{
    $CWD = Get-Location

    # Create CSV File (delete old copy if exists)
    $CSVPath = "$CWD\cache\report.csv"
    if (Test-Path $CSVPath) {
        Remove-Item $CSVPath
    }
    Add-Content -Path $CSVPath  -Value '"Admin","Logged In To","Can Become Admin"'

    # Build a list of Enterprise and Domain Admins - this is who we're hunting
    $HuntedGroups = @("Domain Admins", "Enterprise Admins")

    $Hunted = @()
    foreach($GroupPath in $HuntedGroups){
        $Group = Get-Content "$CWD\cache\groups\$GroupPath" | ConvertFrom-Json
        foreach($Member in $Group.members){
            $UserName = Get-Last-Slash($Member)
            $Hunted += $UserName
            if (-not ($Hunted -contains $UserName)){
                $Hunted += $UserName
            }
        }
    }

    # We get false positives when pulling sessions
    # The job sees this user logged in
    # Remove from hunted so we don't have false positives in the report
    # Bug to fix: https://github.com/ericalexanderorg/easyhound/issues/4
    $Hunted = $Hunted| Where-Object{-not($_ -eq $env:UserName)}

    # Find all nodes where the hunted are logged in and non-admins can also login
    Get-ChildItem -Path "$CWD\cache\nodes" | ForEach-Object {
        $Path = $_.FullName
        $Node = Get-Content $Path | ConvertFrom-Json

        if ("sessions" -in $Node.PSobject.Properties.Name){
            foreach($Session in $Node.sessions){
                $SessionUserName = Get-Last-Slash($Session)
                if ($Hunted -contains $SessionUserName){
                    if ("admins" -in $Node.PSobject.Properties.Name){
                        foreach($LocalAdmin in $Node.admins){
                            $LocalAdmin = Get-Last-Slash($LocalAdmin)
                            if (-not (($HuntedGroups -contains $LocalAdmin) -or ($Hunted -contains $LocalAdmin))){
                                # Got a hit
                                $NodeName = $Node.name
                                $DomainAdmin = $SessionUserName
                                $NotDomainAdmin = $LocalAdmin
                                Add-Content -Path $CSVPath "$DomainAdmin,$NodeName,$NotDomainAdmin"
                            }
                        }
                    }
                }
            }
        }
    }
    Write-Host "Report written to $CWD\report.csv"
}

function Create-Cache{
    if (-not (Test-Path ".\cache")){
        New-Item -Path '.\cache' -ItemType Directory
        New-Item -Path '.\cache\groups' -ItemType Directory
        New-Item -Path '.\cache\nodes' -ItemType Directory
        #New-Item -Path '.\cache\users' -ItemType Directory
    }

}

function Debug($Message){
    Write-Host $Message
}

function Cache-Generic{
    param (
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)){
        # Cache object does not exist, create it.
        $New = [PSCustomObject]@{
            name = Get-Last-Slash($Path)
        }

        # Convert our object to JSON and cache
        $New | ConvertTo-Json | Set-Content -Path $Path
    }
}

function Get-Last-Slash($Path){
    $a = $Path.Split("\")
    return $a[$a.count-1]
}

function Main {
    # Create our cache directory to store data
    Debug("Create-Cache")
    Create-Cache

    # Pull list of computers from AD and query
    Debug("Get-Alive-Nodes")
    Get-Nodes

    # Get domain/enterprise admins
    Debug("Get-Domain-Group-Members-Domain-Admins")
    Get-Domain-Group-Members("Domain Admins")
    Debug("Get-Domain-Group-Members-Enterprise-Admins")
    Get-Domain-Group-Members("Enterprise Admins")

    # Generate report using data in our cache
    Debug("Generate-Report")
    Generate-Report

}

if ($GetNodeData){
    Get-Node-Data -NodeName $NodeName -DomainName $DomainName -CWD $CWD
}
elseif ($ReportOnly){
    Generate-Report
}
else {
    Main
}






