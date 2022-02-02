$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Json = "get_local_admin_$((Get-Date).ToFileTimeUtc()).json"
$Output = Get-LocalGroupMember -Group Administrators -EA 0 | Select-Object ObjectClass, Name, PrincipalSource |
ForEach-Object { if ($Param.Filter) { $_ | Where-Object { $_.Name -match $Param.Filter }} else { $_ }}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }