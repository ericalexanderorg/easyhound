param
(
    [string]$ForceValidateAlive = $False
)

$CWD = Get-Location

. "$CWD\shared.ps1"

function Get-Nodes($threads) {
    $Domain = Get-ADDomain
    $DomainName = $Domain.NetBIOSName

    # Check if we already have a cache of nodes
    $Nodes = Get-ChildItem '.\cache\nodes\' | Measure-Object
    if ($Nodes.count -eq 0){
        # We don't have a cache of nodes from AD, pull it
        try {
            # Only interested in enabled Nodes
            Get-ADComputer -Filter * | ForEach-Object {
                # Create a cache object for this Node if it doesn't exist
                $Path = '.\cache\nodes\' + $_.DNSHostName
                if (-not (Test-Path -Path $Path)) { 
                    # Node does not exist in our cache, create it
                    $New = [PSCustomObject]@{
                        name = $_.DNSHostName
                    }
                    
                    # Convert our object to JSON and ache
                    $New | ConvertTo-Json | Set-Content -Path $Path
                }
            }
        }
        catch {
            Debug "Error pulling nodes from AD. Exiting!"
            Exit 1
        }
    }

    # Multi-threaded node data retrieval
    # Mostly borrowed from: https://github.com/mrhvid/Start-Multithread/blob/master/Start-Multithread.psm1
    $i = 0
    $Jobs = @()
    $SleepTime = 5000
    $Nodes = Get-ChildItem -Path 'cache\nodes'
    $Nodes | ForEach-Object {
        $Path = $_.FullName
        Debug("Processing $Path")
        # Wait for running jobs to finnish if MaxThreads is reached
        $MaxThreads = $Nodes.count / 20
        While((Get-Job -State Running).count -ge $MaxThreads) {
            Write-Progress -Id 1 -Activity 'Waiting for existing jobs to complete' -Status "$($(Get-job -State Running).count) jobs running" -PercentComplete ($i / $Nodes.Count * 100)
            Write-Verbose -Message 'Waiting for jobs to finish before starting new ones'
            Start-Sleep -Milliseconds $SleepTime 
        }

        # Start new jobs 
        # Powershell mult-threading is a PITA!
        # Can't just Start-Job with a Invoke-Command to a remote host
        # Have to Start-Job, Invoke-Expression, that then Invoke-Command's - gross
        $i++
        $Node = Get-Content $Path | ConvertFrom-Json
        if (Test-Connection -ComputerName $Node.name -Count 1 -Quiet){
            $Script = {
                param(
                    [string]$NodeName,
                    [string]$CWD,
                    [string]$DomainName
                )
                $expression = "$CWD\get_sessions.ps1 -NodeName $NodeName -CWD $CWD -Domain $DomainName"
                Write-Host $expression
                Invoke-Expression $expression
            }
            $Jobs += Start-Job -ScriptBlock $Script -ArgumentList $Node.name,$CWD,$DomainName
            $Script = {
                param(
                    [string]$NodeName,
                    [string]$CWD
                )
                Invoke-Expression "$CWD\get_admins.ps1 -NodeName $NodeName -CWD $CWD"
            }
            $Jobs += Start-Job -ScriptBlock $Script -ArgumentList $Node.name,$CWD
        }
        Write-Progress -Id 1 -Activity 'Starting jobs' -Status "$($(Get-job -State Running).count) jobs running" -PercentComplete ($i / $Nodes.Count * 100)
        Write-Verbose -Message "Job with id: $($LastJob.Id) just started."
    }

    # All jobs have now been started
    Write-Verbose -Message "All jobs have been started $(Get-Date)"
    
    # Wait for jobs to finish
    While((Get-Job -State Running).count -gt 0) {
    
        $JobsStillRunning = ''
        foreach($RunningJob in (Get-Job -State Running)) {
            $JobsStillRunning += "$($RunningJob.Name) "
        }

        Write-Progress -Id 1 -Activity 'Waiting for jobs to finish' -Status "$JobsStillRunning"  -PercentComplete (($Node.Count - (Get-Job -State Running).Count) / $Node.Count * 100)
        Write-Verbose -Message "Waiting for following $((Get-Job -State Running).count) jobs to stop $JobsStillRunning"
        Start-Sleep -Milliseconds $SleepTime
    }

    # Output
    Write-Verbose -Message 'Recieving jobs'
    Get-job | Receive-Job 

    # Cleanup 
    Get-job | Remove-Job
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

function Get-Found-Group-Members{
    Get-ChildItem -File -Path 'cache\groups' | ForEach-Object {
        Get-Domain-Group-Members($_)
    }
}

function Add-Members{
    param(
        [array]$Array,
        [string]$GroupPath
    )

    if (Test-Path -Path $GroupPath){
        $Group = Get-Content $GroupPath | ConvertFrom-Json
        foreach ($Member in $Group.members){
            if (-not ($Array -contains $Member)){
                $Array += $Member
            }
        }
    }

    return $Array
}

function Convert-Path-To-Name($Path){
    $Arr = $Path.Split("\")
    return $Arr[3]
}


function Generate-Report{
    $CWD = Get-Location

    # Create CSV File
    $CSVPath = "$CWD\cache\report.csv"
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

    # Find all nodes where the hunted are logged in and non-admins can also login
    Get-ChildItem -Path "$CWD\cache\nodes" | ForEach-Object {
        $Path = $_.FullName
        $Node = Get-Content $Path | ConvertFrom-Json

        if ("sessions" -in $Node.PSobject.Properties.Name){
            foreach ($Admin in $Hunted){
                if (Get-Last-Slash($Node.sessions) -eq Get-Last-Slash($Admin)){
                    # We found an admin logged in
                    if ("admins" -in $Node.PSobject.Properties.Name){
                        foreach($LocalAdmin in $Node.admins){
                            $LocalAdmin = Get-Last-Slash($LocalAdmin)
                            if (-not ($HuntedGroups -contains $LocalAdmin)){
                                # Got a hit
                                $NodeName = $Node.name
                                $DomainAdmin = Get-Last-Slash($Admin)
                                $NotDomainAdmin = Get-Last-Slash($LocalAdmin)
                                Add-Content -Path $CSVPath  -Value "$DomainAdmin","$NodeName","$NotDomainAdmin"
                                #Write-Host "Found $DomainAdmin logged in to $NodeName and $NotDomainAdmin can also login"
                            }
                        }
                    }
                }
            }
        }
    }


}

function Create-Cache{
    if (-not (Test-Path ".\cache")){
        New-Item -Path '.\cache' -ItemType Directory
        New-Item -Path '.\cache\groups' -ItemType Directory
        New-Item -Path '.\cache\nodes' -ItemType Directory
        New-Item -Path '.\cache\users' -ItemType Directory
    }

}

function Debug($Message){
    Write-Host $Message
}

function Main {
    # Create our cache directory to store data
    Debug("Create-Cache")
    Create-Cache

    # Pull list of computers from AD and cache
    # Port scan the list
    # Pull session and admin data from alive list
    Debug("Get-Nodes")
    Get-Nodes

    # Get domain group members
    Debug("Get-Found-Group-Members")
    Get-Found-Group-Members
    # Always get these group members
    Debug("Get-Domain-Group-Members-Domain-Admins")
    Get-Domain-Group-Members("Domain Admins")
    Debug("Get-Domain-Group-Members-Enterprise-Admins")
    Get-Domain-Group-Members("Enterprise Admins")

    # Generate report using data in our cache
    Debug("Generate-Report")
    Generate-Report

}

#Main
Generate-Report



