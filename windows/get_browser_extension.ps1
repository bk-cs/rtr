$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Json = "get_browser_extension_$((Get-Date).ToFileTimeUtc()).json"
$Output = foreach ($User in (Get-WmiObject Win32_UserProfile | Where-Object {
$_.localpath -notmatch 'Windows' }).localpath) {
    foreach ($ExtPath in @('AppData\Local\Google\Chrome\User Data\Default\Extensions',
    'AppData\Local\Microsoft\Edge\User Data\Default\Extensions')) {
        $Path = Join-Path $User $ExtPath
        if (Test-Path $Path) {
            foreach ($Folder in (Get-ChildItem $Path | Where-Object { $_.Name -ne 'Temp' })) {
                foreach ($Item in (Get-ChildItem $Folder.FullName)) {
                    $Json = Join-Path $Item.FullName manifest.json
                    if (Test-Path $Json) {
                        Get-Content $Json | ConvertFrom-Json | ForEach-Object {
                            [PSCustomObject] @{
                                Username = $User | Split-Path -Leaf
                                Browser  = if ($ExtPath -match 'Chrome') { 'Chrome' } else { 'Edge' }
                                Name     = if ($_.Name -notlike '__MSG*') { $_.Name } else {
                                    $Id = ($_.Name -replace '__MSG_','').Trim('_')
                                    @('_locales\en_US','_locales\en').foreach{
                                        $Msg = Join-Path -Path (
                                            Join-Path -Path $Item.Fullname -ChildPath $_) -ChildPath messages.json
                                        if (Test-Path -Path $Msg) {
                                            $App = Get-Content $Msg | ConvertFrom-Json
                                            (@('appName','extName','extensionName','app_name',
                                            'application_title',$Id).foreach{
                                                if ($App.$_.message) {
                                                    $App.$_.message
                                                }
                                            }) | Select-Object -First 1
                                        }
                                    }
                                }
                                Id       = $Folder.Name
                                Version  = $_.Version
                            } | ForEach-Object { if ($Param.Filter) {
                                $_ | Where-Object { $_.Extension -match $Param.Filter }} else { $_ }
                            }
                        }
                    }
                }
            }
        }
    }
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }