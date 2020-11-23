param(
    [string]$NodeName,
    [string]$CWD
)

# Include easyhound.ps1 so we can call shared functions
. "$CWD\shared.ps1"

$NodePath = "$CWD\cache\nodes\$NodeName"

# Get local admin group members
try{
    $Principals = Invoke-Command -ScriptBlock {Get-LocalGroupMember Administrators} -ComputerName $NodeName
}
catch {
    continue
}

foreach($Principal in $Principals){
    if ($Principal.PrincipalSource -eq "ActiveDirectory"){
        if ($Principal.ObjectClass -eq "Group"){
            $Name = Get-Last-Slash($Principal.Name)
            $PrincipalPath = "$CWD\cache\groups\$Name"
            Cache-Generic -Path $PrincipalPath
        }
        if ($Principal.ObjectClass -eq "User"){
            $Name = Get-Last-Slash($Principal.Name)
            $PrincipalPath = "$CWD\cache\users\$Name"
            Cache-Generic -Path $PrincipalPath
        }

        $Node = Get-Content $NodePath | ConvertFrom-Json

        if ("admins" -in $Node.PSobject.Properties.Name){
            if (-not ($Node.admins -contains $PrincipalPath)){
                $Node.admins += $PrincipalPath
            }
        }
        else{
            # Object doesn't have a user_admins property
            $Admins = @($PrincipalPath)
            $Node | Add-Member -NotePropertyName "admins" -NotePropertyValue $Admins
        }
    
        $Node | ConvertTo-Json | Set-Content -Path $NodePath
    }
}
