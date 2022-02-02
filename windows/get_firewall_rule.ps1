$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Json = "get_firewall_rule_$((Get-Date).ToFileTimeUtc()).json"
$Output = Get-NetFirewallRule -EA 0 | Select-Object Name, DisplayName, DisplayGroup, Enabled, Profile, Direction,
Action, EdgeTraversalPolicy, LooseSourceMapping, LocalOnlyMapping, Owner, PrimaryStatus, EnforcementStatus,
PolicyStoreSource, PolicyStoreSourceType | ForEach-Object {
    $_.PSObject.Properties | ForEach-Object {
        if ($_.Value -and $_.Value.ToString() -and $_.Value -isnot [array]) {
            $_.Value = $_.Value.ToString()
        }
    }
    if ($Param.Filter) {
        $_ | Where-Object { $_.Name -match $Param.Filter -or $_.DisplayName -match $Param.Filter -or
            $_.DisplayGroup -match $Param.Filter }
    } else {
        $_
    }
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }