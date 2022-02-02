$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$JsonFile = "get_service_$((Get-Date).ToFileTimeUtc()).json"
$Output = Get-WmiObject Win32_Service -EA 0 | Select-Object ProcessId, Name, PathName | ForEach-Object {
    if ($Param.Filter) {
        $_ | Where-Object { $_.Name -match $Param.Filter -or $_.PathName -match $Param.Filter }
    } else {
        $_
    }
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$JsonFile" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }