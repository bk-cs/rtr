$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Json = "get_local_share_$((Get-Date).ToFileTimeUtc()).json"
$Output = Get-SmbShare -EA 0 | Select-Object Name, ScopeName, Description, Path
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }