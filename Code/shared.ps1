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