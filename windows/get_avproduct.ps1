$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct -ErrorAction 0 |
    Select-Object DisplayName, ProductState
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_avproduct.json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }