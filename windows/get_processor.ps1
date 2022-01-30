$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-WmiObject -ClassName Win32_Processor -EA 0 | Select-Object ProcessorId, Caption, DeviceID,
    Manufacturer, MaxClockSpeed, SocketDesignation, Name
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_processor.json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }