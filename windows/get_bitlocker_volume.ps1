$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-BitLockerVolume -EA 0 | ConvertTo-Json -Compress
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output >> "$Rtr\get_bitlocker_volume_$((Get-Date).ToFileTimeUtc()).json"
}
$Output