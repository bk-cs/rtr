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
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
@('Hostname','ClientId','ClientSecret').foreach{
    if (!$Param.$_) {
        throw "Missing required parameter '$_'."
    } elseif ($_ -eq 'Hostname') {
        if ($Param.$_ -notmatch 'https://api(.(eu-1|laggar.gcw|us-2))?.crowdstrike.com') {
            throw "'$($Param.$_)' is not a valid API hostname value."
        }
    } elseif ($_ -match '^Client') {
        if (($_ -match 'Id$' -and $Param.$_ -notmatch '^\w{32}$') -or ($_ -match 'Secret$' -and
        $Param.$_ -notmatch '^\w{40}$')) {
            throw "'$($Param.$_)' is not a valid '$_' value."
        }
    }
}
$File = validate $Param.File
if (!$File) {
    throw "Missing required parameter 'File'."
} elseif ((Test-Path $File) -eq $false) {
    throw "Cannot find path '$File' because it does not exist."
} elseif ((Test-Path $File -PathType Leaf) -eq $false) {
    throw "'File' must be a file."
}
if (!($PSVersionTable.CLRVersion.ToString() -ge 3.5)) { throw '.NET Framework 3.5 or newer is required' }
if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { throw $_ }
}
$Falcon = @{
    ApiClient = "client_id=$($Param.ClientId)&client_secret=$($Param.ClientSecret)"
    WebClient = New-Object System.Net.WebClient
}
if ($Param.MemberCid) {
    $Falcon.ApiClient += "&member_cid=$($Param.MemberCid)"
}
$Falcon.WebClient.BaseAddress = $Param.Hostname
$Falcon.WebClient.Encoding = [System.Text.Encoding]::UTF8
$EnvId = if ((gwmi -Class Win32_OperatingSystem).Caption -match 'Windows 10') {
    160
} elseif ([Environment]::Is64BitOperatingSystem -eq $true) {
    110
} else {
    100
}
$Comment = "$($env:COMPUTERNAME)_$((Get-Date).ToFileTimeUtc())"
$Sample = try {
    falcon @{ Uri = "/samples/entities/samples/v3?file_name=$($File | Split-Path -Leaf)&comment=$Comment";
        Method = 'POST'; Headers = @{ Accept = 'application/json'; 'Content-Type' = 'application/octet-stream' };
        File = $File }
} catch {
    throw 'Failed sample upload.'
}
$Sha256 = [regex]::Matches($Sample,'"sha256": "(?<sha256>\w{64})",?')[0].Groups['sha256'].Value
$Submit = try {
    falcon @{ Uri = '/falconx/entities/submissions/v1'; Method = 'POST'; Headers = @{ Accept =
        'application/json'; 'Content-Type' = 'application/json' }; Body = '{"sandbox":[{"environment_id":' +
        $EnvId + ',"sha256":"' + $Sha256 + '","submit_name":"' + $Comment + '"}]}' }
} catch {
    throw 'Failed submission to Falcon X Sandbox.'
}
$Output = @{
    SubmissionId    = [regex]::Matches($Submit,'"id": "(?<id>\w{32}_\w{32})",?')[0].Groups['id'].Value
    SubmissionName  = $Comment
    QuotaTotal      = [regex]::Matches($Submit,'"total": (?<total>\d+),?')[0].Groups['total'].Value
    QuotaUsed       = [regex]::Matches($Submit,'"used": (?<used>\d+),?')[0].Groups['used'].Value
    QuotaInProgress = [regex]::Matches($Submit,'"in_progress": (?<in_progress>\d+),?')[0].Groups[
        'in_progress'].Value
}
output $Output $Param "submit_sandbox_$((Get-Date).ToFileTimeUtc()).json"