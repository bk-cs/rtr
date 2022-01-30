$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = [PSCustomObject] @{ LastBootUpTime =
    (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime.ToFileTimeUtc() } | ConvertTo-Json -Compress
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output >> "$Rtr\get_last_boot.json"
}
$Output