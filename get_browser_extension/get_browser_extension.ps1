function output ([object] $Obj, [object] $Param, [string] $Json) {
    if ($Obj -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr -PathType Container) -eq $false) { ni $Rtr -ItemType Directory }
        $O = @{ tags = @{ json = $Json; script = $Json -replace '_\d+\.json$','.ps1';
            host = [System.Net.Dns]::GetHostName() }}
        $R = reg query ('HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-' +
            '7058-48c9-a204-725362b67639}\Default') 2>$null
        if ($R) {
            $O.tags['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
            $O.tags['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
        }
        $Evt = $Obj | % {
            $Att = @{}
            $_.PSObject.Properties | % { $Att[$_.Name]=$_.Value }
            ,@{ timestamp = Get-Date -Format o; attributes = $Att }
        }
        if (($Evt | measure).Count -eq 1) {
            $O['events'] = @($Evt)
            $O | ConvertTo-Json -Depth 8 -Compress >> (Join-Path $Rtr $Json)
        } elseif (($Evt | measure).Count -gt 1) {
            for ($i = 0; $i -lt ($Evt | measure).Count; $i += 200) {
                $C = $O.Clone()
                $C['events'] = $Evt[$i..($i + 199)]
                $C | ConvertTo-Json -Depth 8 -Compress >> (Join-Path $Rtr $Json)
            }
        }
    }
    $Obj | ConvertTo-Json -Compress
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Out = foreach ($User in (gwmi Win32_UserProfile | ? { $_.localpath -notmatch 'Windows' }).localpath) {
    foreach ($ExtPath in @('AppData\Local\Google\Chrome\User Data\Default\Extensions',
    'AppData\Local\Microsoft\Edge\User Data\Default\Extensions')) {
        $Path = Join-Path $User $ExtPath
        if (Test-Path $Path -PathType Container) {
            foreach ($Folder in (gci $Path | ? { $_.Name -ne 'Temp' })) {
                foreach ($Item in (gci $Folder.FullName)) {
                    $Json = Join-Path $Item.FullName manifest.json
                    if (Test-Path $Json -PathType Leaf) {
                        gc $Json | ConvertFrom-Json | % {
                            [PSCustomObject] @{
                                Username = $User | Split-Path -Leaf
                                Browser = if ($ExtPath -match 'Chrome') { 'Chrome' } else { 'Edge' }
                                Name = if ($_.name -notlike '__MSG*') { $_.name } else {
                                    $Id = ($_.name -replace '__MSG_','').Trim('_')
                                    @('_locales\en_US','_locales\en').foreach{
                                        $Msg = Join-Path (Join-Path $Item.Fullname $_) messages.json
                                        if (Test-Path -Path $Msg -PathType Leaf) {
                                            $App = gc $Msg | ConvertFrom-Json
                                            (@('appName','extName','extensionName','app_name',
                                            'application_title',$Id).foreach{
                                                if ($App.$_.message) {  $App.$_.message }
                                            }) | select -First 1
                                        }
                                    }
                                }
                                Id = $Folder.Name
                                Version = $_.version
                                ManifestVersion = $_.manifest_version
                                ContentSecurityPolicy = $_.content_security_policy
                                OfflineEnabled = if ($_.offline_enabled) { $_.offline_enabled } else { $false }
                                Permissions = $_.permissions
                            } | % {
                                if ($Param.Filter) { $_ | ? { $_.Extension -match $Param.Filter }} else { $_ }
                            }
                        }
                    }
                }
            }
        }
    }
}
output $Out $Param "get_browser_extension_$((Get-Date).ToFileTimeUtc()).json"