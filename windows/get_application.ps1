function Get-RegistryKey ([string] $String) {
    $Object = foreach ($Name in (Get-ChildItem 'Registry::\').PSChildName) {
        if ($Name -eq 'HKEY_USERS') {
            foreach ($Value in (Get-ChildItem "Registry::\$Name" -EA 0 | Where-Object {
            $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' }).PSChildName) {
                if (Test-Path "Registry::\$Name\$Value\$String") {
                    Get-ChildItem "Registry::\$Name\$Value\$String" -EA 0
                }
            }
        } elseif (Test-Path "Registry::\$Name\$String") {
            Get-ChildItem "Registry::\$Name\$String" -EA 0
        }
    }
    $Object | ForEach-Object {
        $Item = [PSCustomObject] @{}
        foreach ($Property in $_.Property) {
            $Item.PSObject.Properties.Add((New-Object PSNoteProperty($Property,($_.GetValue($Property)))))
        }
        $Item
    }
}
function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Output = @('Microsoft\Windows\CurrentVersion\Uninstall',
'Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall').foreach{
    Get-RegistryKey "Software\$_" | Where-Object { $_.DisplayName -and $_.DisplayVersion -and $_.Publisher } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation | ForEach-Object {
        if ($Param.Filter) { $_ | Where-Object { $_.DisplayName -match $Param.Filter }} else { $_ }
    }
}
Write-Output $Output $Param "get_application_$((Get-Date).ToFileTimeUtc()).json"