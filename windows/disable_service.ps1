$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Service = Get-Service | Where-Object { $_.Name -eq $Param.Name }
if (!$Service) {
    throw "No results for service '$($Param.Name)'."
}
if ($Service.StartType) {
    $Service | Set-Service -StartupType Disabled
}
if ($Service.Status -ne 'Stopped') {
    $Service | Set-Service -Status Stopped
}
$Output = Get-Service -Name $Param.Name | Select-Object Name, Status, StartType | ConvertTo-Json -Compress
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output >> "$Rtr\disable_service.json"
}
$Output