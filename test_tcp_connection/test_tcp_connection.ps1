function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Test-NetConnection -ComputerName $Param.Destination -Port $Param.Port | Select-Object ComputerName,
RemoteAddress, RemotePort, SourceAddress, InterfaceAlias, TcpTestSucceeded | ForEach-Object {
    if ($_.RemoteAddress) { $_.RemoteAddress = $_.RemoteAddress.IPAddressToString }
    if ($_.SourceAddress) { $_.SourceAddress = $_.SourceAddress.IPv4Address }
    $_
}
Write-Output $Output $Param "$Rtr\test_tcp_connection_$((Get-Date).ToFileTimeUtc()).json"