$Humio = @{ Cloud = ''; Token = '' }
switch ($Humio) {
    { $_.Cloud -and $_.Cloud -notmatch '/$' } { $_.Cloud += '/' }
    { ($_.Cloud -and !$_.Token) -or ($_.Token -and !$_.Cloud) } {
        throw "Both 'Cloud' and 'Token' are required when sending results to Humio."
    }
    { $_.Cloud -and $_.Cloud -notmatch '^https://cloud(.(community|us))Where-Object.humio.com/$' } {
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
function sendlist ([object]$Obj,[object]$Humio,[string]$Script) {
    if ($Obj -and $Humio.Cloud -and $Humio.Token) {
        $Iwr = @{ Uri = @($Humio.Cloud,'api/v1/ingest/humio-structured/') -join $null; Method = 'post';
            Headers = @{ Authorization = @('Bearer',$Humio.Token) -join ' '; ContentType = 'application/json' }}
        $A = @{ script = $Script; host = [System.Net.Dns]::GetHostName() }
        $R = reg query 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CSAgent\Sim' 2>$null
        if ($R) {
            $A['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
            $A['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
        }
        $E = @($Obj).foreach{
            $C = $A.Clone()
            @($_.PSObject.Properties).foreach{ $C[$_.Name]=$_.Value }
            ,@{ timestamp = Get-Date -Format o; attributes = $C }
        }
        for ($i = 0; $i -lt ($E | Measure-Object).Count; $i += 200) {
            $B = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @(@($E)[$i..($i + 199)]) }
            $Req = try { Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($B) -Compress) -UseBasicParsing } catch {}
            if ($Req.StatusCode -ne 200) {
                $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
                $Json = $Script -replace '\.ps1',"_$((Get-Date).ToFileTimeUtc()).json"
                if ((Test-Path $Rtr -PathType Container) -eq $false) { [void](New-Item $Rtr -ItemType Directory) }
                ConvertTo-Json @($B) -Compress >> (Join-Path $Rtr $Json)
            }
        }
    }
}
$Out = foreach ($User in (Get-CimInstance Win32_UserProfile | Where-Object { $_.localpath -notmatch
'Windows' }).localpath) {
    foreach ($ExtPath in @('Google\Chrome','Microsoft\Edge')) {
        $Path = Join-Path $User "AppData\Local\$ExtPath\User Data\Default\Extensions"
        if (Test-Path $Path -PathType Container) {
            foreach ($Folder in (Get-ChildItem $Path | Where-Object { $_.Name -ne 'Temp' })) {
                foreach ($Item in (Get-ChildItem $Folder.FullName)) {
                    $Json = Join-Path $Item.FullName manifest.json
                    if (Test-Path $Json -PathType Leaf) {
                        Get-Content $Json | ConvertFrom-Json | ForEach-Object {
                            [PSCustomObject]@{
                                Username = $User | Split-Path -Leaf
                                Browser = if ($ExtPath -match 'Chrome') { 'Chrome' } else { 'Edge' }
                                Name = if ($_.name -notlike '__MSG*') { $_.name } else {
                                    $Id = ($_.name -replace '__MSG_','').Trim('_')
                                    @('_locales\en_US','_locales\en').foreach{
                                        $Msg = Join-Path (Join-Path $Item.Fullname $_) messages.json
                                        if (Test-Path -Path $Msg -PathType Leaf) {
                                            $App = Get-Content $Msg | ConvertFrom-Json
                                            (@('appName','extName','extensionName','app_name','application_title',
                                            $Id).foreach{
                                                if ($App.$_.message) { $App.$_.message }
                                            }) | Select-Object -First 1
                                        }
                                    }
                                }
                                Id = $Folder.Name
                                Version = $_.version
                                ManifestVersion = $_.manifest_version
                                ContentSecurityPolicy = $_.content_security_policy
                                OfflineEnabled = if ($_.offline_enabled) { $_.offline_enabled } else { $false }
                                Permissions = $_.permissions
                            }
                        }
                    }
                }
            }
        }
    }
}
sendlist $Out $Humio 'list_browser_extension.ps1'
$Out | ConvertTo-Json -Compress