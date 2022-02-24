function output ([object] $Obj, [object] $Param, [string] $Script) {
    if ($Obj -and $Param.Cloud -and $Param.Token) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr -PathType Container) -eq $false) { ni $Rtr -ItemType Directory }
        $Json = $Script -replace '\.ps1', "_$((Get-Date).ToFileTimeUtc()).json"
        $Iwr = @{ Uri = @($Param.Cloud, 'api/v1/ingest/humio-structured/') -join $null; Method = 'post';
            Headers = @{ Authorization = @('Bearer', $Param.Token) -join ' '; ContentType = 'application/json' }}
        $A = @{ script = $Script; host = [System.Net.Dns]::GetHostName() }
        $R = reg query ('HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-' +
            '7058-48c9-a204-725362b67639}\Default') 2>$null
        if ($R) {
            $A['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
            $A['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
        }
        $E = @($Obj).foreach{
            $_.PSObject.Properties | % { $A[$_.Name]=$_.Value }
            ,@{ timestamp = Get-Date -Format o; attributes = $A }
        }
        for ($i = 0; $i -lt ($E | measure).Count; $i += 200) {
            $B = @{events=@($E[$i..($i + 199)])}
            $Req = try { iwr @Iwr -Body (ConvertTo-Json @($B) -Depth 8 -Compress) -UseBasicParsing } catch {}
            if ($Req.StatusCode -ne 200) {
                ConvertTo-Json @($B) -Depth 8 -Compress >> (Join-Path $Rtr $Json)
            }
        }
    }
    $Obj | ConvertTo-Json -Depth 8 -Compress
}
function parse ([string] $String) {
    $Param = try { $String | ConvertFrom-Json } catch { throw $_ }
    switch ($Param) {
        { $_.Cloud -and $_.Cloud -notmatch '/$' } {
            $_.Cloud += '/'
        }
        { ($_.Cloud -and -not $_.Token) -or ($_.Token -and -not $_.Cloud) } {
            throw "Both 'Cloud' and 'Token' are required when sending results to Humio."
        }
        { $_.Cloud -and $_.Cloud -notmatch '^https://cloud(.(community|us))?.humio.com/$' } {
            throw "'$($_.Cloud)' is not a valid Humio cloud value."
        }
        { $_.Token -and $_.Token -notmatch '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$' } {
            throw "'$($_.Token)' is not a valid Humio ingest token."
        }
        { $_.Cloud -and $_.Token -and [Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12' } {
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            } catch {
                throw $_
            }
        }
    }
    $Param
}
$Param = if ($args[0]) { parse $args[0] }
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
output $Out $Param "get_browser_extension.ps1"