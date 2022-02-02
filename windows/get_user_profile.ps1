$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Json = "get_user_profile_$((Get-Date).ToFileTimeUtc()).json"
$Output = Get-WmiObject win32_userprofile | Where-Object { $_.SID -match '^S-1-5-21' } | Select-Object Sid,
    LocalPath, RoamingPath, RoamingConfigured, LastUseTime
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }