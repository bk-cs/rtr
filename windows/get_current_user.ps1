$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-Process -IncludeUserName -EA 0 | Where-Object { $_.SessionId -ne 0 } | Select-Object SessionId,
    UserName | Sort-Object -Unique
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_current_user_$(
        (Get-Date).ToFileTimeUtc()).json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }