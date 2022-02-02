$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Test-NetConnection -ComputerName $Param.Destination -Port $Param.Port | Select-Object ComputerName,
RemoteAddress, RemotePort, SourceAddress, InterfaceAlias, TcpTestSucceeded | ForEach-Object {
    if ($_.RemoteAddress) { $_.RemoteAddress = $_.RemoteAddress.IPAddressToString }
    if ($_.SourceAddress) { $_.SourceAddress = $_.SourceAddress.IPv4Address }
    $_ | ConvertTo-Json -Compress
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output >> "$Rtr\test_tcp_connection_$((Get-Date).ToFileTimeUtc()).json"
}
$Output