$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-NetRoute -EA 0 | Select-Object DestinationPrefix, InterfaceIndex, InterfaceAlias, AddressFamily,
    NextHop, Publish, State, RouteMetric, InterfaceMetric, Protocol, PolicyStore
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_network_route.json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }