$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-NetNeighbor -EA 0 | Select-Object IPAddress, InterfaceIndex, InterfaceAlias, AddressFamily,
    LinkLayerAddress, State, PolicyStore
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_arp.json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }