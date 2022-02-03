function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-NetConnectionProfile -EA 0 | Select-Object Name, InterfaceAlias, InterfaceIndex, NetworkCategory,
IPv4Connectivity, IPv6Connectivity | ForEach-Object {
    $_.PSObject.Properties | ForEach-Object { if ($_.Value.ToString()) { $_.Value = $_.Value.ToString() }}
    $_
}
Write-Output $Output $Param "get_network_profile_$((Get-Date).ToFileTimeUtc()).json"