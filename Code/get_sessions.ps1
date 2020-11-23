param(
    [string]$NodeName,
    [string]$CWD,
    [string]$Domain
)

# Include easyhound.ps1 so we can call shared functions
. "$CWD\shared.ps1"

$NodePath = "$CWD\cache\nodes\$NodeName"

$Processes = Invoke-Command -ScriptBlock { Get-Process -IncludeUserName | Select-Object UserName -Unique } -ComputerName $NodeName

$UserNames = @()
foreach($Process in $Processes){
    $UserName = $Process.UserName
    if ($UserName -match "^$Domain"){
        $UserName = Get-Last-Slash($UserName)
        if (-not ($UserNames -contains $UserName)){
            $UserNames += $UserName
        }
    }
}

foreach ($UserName in $UserNames){
    $SessionPath = "$CWD\cache\users\$UserName"
    Cache-Generic -Path $SessionPath
    $Node = Get-Content $NodePath | ConvertFrom-Json
    if ("sessions" -in $Node.PSobject.Properties.Name){
        if (-not ($Node.sessions -contains $SessionPath)){
            $Node.sessions += $SessionPath
        }
    }
    else{
        # Object doesn't have a sessions property
        $Sessions = @($SessionPath)
        $Node | Add-Member -NotePropertyName "sessions" -NotePropertyValue $Sessions
    }

    $Node | ConvertTo-Json | Set-Content -Path $NodePath
}




