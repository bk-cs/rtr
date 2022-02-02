$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = foreach ($V in (Get-ChildItem "Registry::\HKEY_USERS" -EA 0 | Where-Object {
$_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' }).PSChildName) {
    Get-ChildItem "Registry::\HKEY_USERS\$V\Network" -EA 0 | ForEach-Object {
        [PSCustomObject] @{
            Share      = $_.PSChildName
            RemotePath = $_.GetValue('RemotePath')
            UserName   = (Get-WmiObject Win32_UserAccount | Where-Object { $_.SID -eq $V }).Name
            Sid        = $V
        }
    }
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_remote_share_$(
        (Get-Date).ToFileTimeUtc()).json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }