function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-LocalGroupMember -Group Administrators -EA 0 | Select-Object ObjectClass, Name, PrincipalSource |
ForEach-Object { if ($Param.Filter) { $_ | Where-Object { $_.Name -match $Param.Filter }} else { $_ }}
Write-Output $Output $Param "get_local_admin_$((Get-Date).ToFileTimeUtc()).json"