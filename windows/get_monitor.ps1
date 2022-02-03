function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -EA 0 | Select-Object ManufacturerName,
UserFriendlyName, SerialNumberID | ForEach-Object {
    $_.PSObject.Properties | Where-Object { $_.Value -is [System.Array] } | ForEach-Object {
        $_.Value = ([System.Text.Encoding]::ASCII.GetString($_.Value -notmatch 0))
    }
    $_
}
Write-Output $Output $Param "get_monitor_$((Get-Date).ToFileTimeUtc()).json"