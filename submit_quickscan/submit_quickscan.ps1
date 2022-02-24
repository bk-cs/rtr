function falcon ([object] $Obj) {
    if (!$Obj.Method) { $Obj['Method'] = 'GET' }
    if (!$Obj.Headers) { $Obj['Headers'] = @{ Accept = 'application/json' }}
    if ((!$Falcon.Expiration -or $Falcon.Expiration -le (Get-Date).AddSeconds(600)) -and
    $Obj.Uri -ne '/oauth2/token') {
        falcon @{ Uri = '/oauth2/token'; Method = 'POST'; Headers = @{ Accept = 'application/json';
        'Content-Type' = 'application/x-www-form-urlencoded' }; Body = $Falcon.ApiClient } | % {
            if ($_ -match 'expires_in') {
                $Falcon['Expiration'] = (Get-Date).AddSeconds(([regex]::Matches($_,
                '"expires_in": (?<seconds>\d*),')[0].Groups['seconds'].Value))
            }
            if ($_ -match 'access_token') { $Falcon.WebClient.Headers.Add('Authorization',
                (@('bearer',([regex]::Matches($_,'"access_token": "(?<access_token>.*)",')[0].Groups[
                'access_token'].Value) -join ' ')))
            } else { throw 'Failed to retrieve authorization token.' }
        }
    }
    ($Obj.Headers).GetEnumerator().foreach{ $Falcon.WebClient.Headers.Add($_.Key, $_.Value) }
    if ($Obj.Method -eq 'GET' -and $Obj.Outfile) {
        $Falcon.WebClient.DownloadFile($Obj.Uri, $Obj.Outfile)
    } elseif ($Obj.Method -eq 'POST' -and $Obj.File) {
        if ((Test-Path $Obj.File -PathType Leaf) -eq $false) {
            throw "'$($Obj.File)' can not be found or is not a file."
        }
        $ByteContent = gc -Path $Obj.File -Encoding Byte -Raw
        [System.Text.Encoding]::UTF8.GetString($Falcon.WebClient.UploadData($Obj.Uri, $ByteContent))
    } elseif ($Obj.Method -eq 'POST' -and $Obj.Body) {
        $Falcon.WebClient.UploadString($Obj.Uri, $Obj.Body)
    } else {
        $Request = $Falcon.WebClient.OpenRead($Obj.Uri)
        $Stream = New-Object System.IO.StreamReader $Request
        $Stream.ReadToEnd()
        @($Request, $Stream).Where({ $_ }).foreach{ $_.Dispose() }
    }
    if ($Obj.Headers) {
        ($Obj.Headers.Keys).Where({ $Falcon.WebClient.Headers.Get($_) }).foreach{
            $Falcon.WebClient.Headers.Remove($_)
        }
    }
    if ($Falcon.WebClient.ResponseHeaders.Get('X-Ratelimit-RetryAfter')) {
        $Retry = ([System.DateTimeOffset]::FromUnixTimeSeconds($Falcon.WebClient.ResponseHeaders.Get(
            'X-Ratelimit-RetryAfter'))).Second
        sleep $Retry
        falcon $Obj
    }
}
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
            $C = $A.Clone()
            $_.PSObject.Properties | % { $C[$_.Name]=$_.Value }
            ,@{ timestamp = Get-Date -Format o; attributes = $C }
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
function validate ([string] $Str) {
    if (![string]::IsNullOrEmpty($Str)) {
        if ($Str -match 'HarddiskVolume\d+\\') {
            $Def = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint QueryDosDevice(
    string lpDeviceName,
    System.Text.StringBuilder lpTargetPath,
    uint ucchMax);
'@
            $StrBld = New-Object System.Text.StringBuilder(65536)
            $K32 = Add-Type -MemberDefinition $Def -Name Kernel32 -Namespace Win32 -PassThru
            foreach ($Vol in (gwmi Win32_Volume | ? { $_.DriveLetter })) {
                [void] $K32::QueryDosDevice($Vol.DriveLetter,$StrBld,65536)
                $Ntp = [regex]::Escape($StrBld.ToString())
                $Str | ? { $_ -match $Ntp } | % { $_ -replace $Ntp, $Vol.DriveLetter }
            }
        }
        else { $Str }
    }
}
function parse ([string] $String) {
    $Param = try { $String | ConvertFrom-Json } catch { throw $_ }
    switch ($Param) {
        { -not $_.File } {
            throw "Missing required parameter 'File'."
        }
        { $_.File } {
            $_.File = validate $_.File
            if ((Test-Path $_.File -PathType Leaf) -eq $false) {
                throw "Cannot find path '$($_.File)' because it does not exist or is not a file."
            }
        }
        { $_.Cloud -and $_.Cloud -notmatch '/$' } {
            $_.Cloud += '/'
        }
        { $_.Hostname -and $_.Hostname -notmatch '/$' } {
            $_.Hostname += '/'
        }
        { $_.Hostname -and $_.Hostname -notmatch '^https://api(.(eu-1|laggar.gcw|us-2))?.crowdstrike.com/$'} {
            throw "'$($_.Hostname)' is not a valid Falcon API hostname value."
        }
        { $_.ClientId -and $_.ClientId -notmatch '^\w{32}$' } {
            throw "'$($_.ClientId)' is not a valid 'ClientId' value."
        }
        { $_.ClientSecret -and $_.ClientSecret -notmatch '^\w{40}$' } {
            throw "'$($_.ClientSecret)' is not a valid 'ClientSecret' value."
        }
        { $_.MemberCid -and $_.MemberCid -notmatch '^\w{32}$' } {
            throw "'$($_.MemberCid)' is not a valid 'MemberCid' value."
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
        { $_.Hostname -and [Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12' } {
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
if (!($PSVersionTable.CLRVersion.ToString() -ge 3.5)) { throw '.NET Framework 3.5 or newer is required' }
$Falcon = @{
    ApiClient = "client_id=$($Param.ClientId)&client_secret=$($Param.ClientSecret)"
    WebClient = New-Object System.Net.WebClient
}
if ($Param.MemberCid) {
    $Falcon.ApiClient += "&member_cid=$($Param.MemberCid)"
}
$Falcon.WebClient.BaseAddress = $Param.Hostname
$Falcon.WebClient.Encoding = [System.Text.Encoding]::UTF8
$Sam = try {
    falcon @{ Uri = "/samples/entities/samples/v3?file_name=$($Param.File | Split-Path -Leaf)&comment=$Comment";
        Method = 'POST'; Headers = @{ Accept = 'application/json'; 'Content-Type' = 'application/octet-stream' };
        File = $Param.File } | ConvertFrom-Json
} catch {
    throw 'Failed sample upload.'
}
$Sha256 = $Sam.resources.sha256
$Sub = try {
    falcon @{ Uri = '/scanner/entities/scans/v1'; Method = 'POST'; Headers = @{ Accept =
        'application/json'; 'Content-Type' = 'application/json' }; Body = '{"samples":["' + $Sha256 + '"]}' } |
        ConvertFrom-Json
} catch {
    throw 'Failed submission to Falcon X QuickScan.'
}
$Id = $Sub.resources[0]
$Out = [PSCustomObject] @{
    SubmissionId    = $Id
    Sha256          = $Sha256
    Verdict         = 'in_progress'
    QuotaTotal      = $Sub.meta.quota.total
    QuotaUsed       = $Sub.meta.quota.used
    QuotaInProgress = $Sub.meta.quota.in_progress
}
sleep 30
$Res = try {
    falcon @{ Uri = "/scanner/entities/scans/v1?ids=$Id"; Method = 'GET'; Headers = @{ Accept =
        'application/json' }} | ConvertFrom-Json
} catch {}
if ($Res) {
    $Out.Verdict = ($Res.resources.samples | ? { $_.sha256 -eq $Sha256 }).verdict
    $Out.QuotaTotal = $Res.meta.quota.total
    $Out.QuotaUsed = $Res.meta.quota.used
    $Out.QuotaInProgress = $Res.meta.quota.in_progress
}
output $Out $Param "submit_quickscan.ps1"