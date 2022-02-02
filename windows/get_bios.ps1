$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-WmiObject -Class Win32_BIOS | Select-Object Manufacturer, Name, SerialNumber, Version |
    ConvertTo-Json -Compress
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output >> "$Rtr\get_bios_$((Get-Date).ToFileTimeUtc()).json"
}
$Output