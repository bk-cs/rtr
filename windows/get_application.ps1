$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
function grk ($S) {
    $O = foreach ($N in (Get-ChildItem 'Registry::\').PSChildName) {
        if ($N -eq 'HKEY_USERS') {
            foreach ($V in (Get-ChildItem "Registry::\$N" -EA 0 | Where-Object {
            $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' }).PSChildName) {
                if (Test-Path "Registry::\$N\$V\$S") {
                    Get-ChildItem "Registry::\$N\$V\$S" -EA 0
                }
            }
        } elseif (Test-Path "Registry::\$N\$S") {
            Get-ChildItem "Registry::\$N\$S" -EA 0
        }
    }
    $O | ForEach-Object {
        $i = [PSCustomObject] @{}
        foreach ($P in $_.Property) {
            $i.PSObject.Properties.Add((New-Object PSNoteProperty($P,($_.GetValue($P)))))
        }
        $i
    }
}
$Output = @('Microsoft\Windows\CurrentVersion\Uninstall',
'Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall').foreach{
    grk "Software\$_" | Where-Object { $_.DisplayName -and $_.DisplayVersion -and $_.Publisher } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation | ForEach-Object {
        if ($Param.Filter) {
            $_ | Where-Object { $_.DisplayName -match $Param.Filter }
        } else {
            $_
        }
    }
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\get_application.json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }