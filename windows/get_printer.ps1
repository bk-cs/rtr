$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-Printer -EA 0 | Select-Object Name, Type, ShareName, PortName, DriverName, Location, Shared,
    Published, DeviceType, Priority, PrinterStatus
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_printer_$(
        (Get-Date).ToFileTimeUtc()).json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }