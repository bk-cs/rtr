$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = Get-Tpm -EA 0 | Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated, TpmOwned, RestartPending,
    ManufacturerId, ManufacturerIdTxt, ManufacturerVersion, ManagedAuthLevel, OwnerAuth, OwnerClearDisabled,
    AutoProvisioning, LockedOut, LockoutHealTime, LockoutCount, LockoutMax, SelfTest | ConvertTo-Json -Compress
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output >> "$Rtr\get_tpm.json"
}
$Output