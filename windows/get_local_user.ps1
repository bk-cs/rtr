$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-LocalUser -EA 0 | Select-Object Name, FullName, Enabled, Sid, PasswordRequired, PasswordLastSet,
PasswordExpires, PrincipalSource, Description | ForEach-Object {
    $_.PSObject.Properties | ForEach-Object {
        if ($_.Value -is [datetime]) { $_.Value = try { $_.Value.ToFileTimeUtc() } catch { $_.Value }}
    }
    if ($_.Sid) { $_.Sid = $_.Sid.ToString() }
    if ($Param.Filter) { $_ | Where-Object { $_.Name -match $Param.Filter }} else { $_ }
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_local_user_$(
        (Get-Date).ToFileTimeUtc()).json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }