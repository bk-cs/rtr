$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Json = "get_monitor_$((Get-Date).ToFileTimeUtc()).json"
$Output = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -EA 0 | Select-Object ManufacturerName,
UserFriendlyName, SerialNumberID | ForEach-Object {
    $_.PSObject.Properties | Where-Object { $_.Value -is [System.Array] } | ForEach-Object {
        $_.Value = ([System.Text.Encoding]::ASCII.GetString($_.Value -notmatch 0))
    }
    $_
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }