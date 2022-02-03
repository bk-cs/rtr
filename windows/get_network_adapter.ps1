function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-NetAdapter -EA 0 | ForEach-Object {
    $Ip = Get-NetIpAddress -InterfaceIndex $_.IfIndex | Select-Object IPAddress, AddressFamily
    $_ | Select-Object Name, MacAddress, LinkSpeed, Virtual, Status, MediaConnectionState, FullDuplex, DriverName,
    DriverVersionString | ForEach-Object {
        $_.PSObject.Properties.Add((New-Object PSNoteProperty('Ipv4Address',($Ip | Where-Object {
            $_.AddressFamily -eq 'IPv4' }).IPAddress)))
        $_.PSObject.Properties.Add((New-Object PSNoteProperty('Ipv6Address',($Ip | Where-Object {
            $_.AddressFamily -eq 'IPv6'}).IPAddress)))
        $_
    }
}
Write-Output $Output $Param "get_network_adapter_$((Get-Date).ToFileTimeUtc()).json"