function Confirm-FilePath ([string] $String) {
    if ($String -match 'HarddiskVolume\d+\\') {
        $Def = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint QueryDosDevice(
    string lpDeviceName,
    System.Text.StringBuilder lpTargetPath,
    uint ucchMax);
'@
        $StrBld = New-Object System.Text.StringBuilder(65536)
        $K32 = Add-Type -MemberDefinition $Def -Name Kernel32 -Namespace Win32 -PassThru
        foreach ($Vol in (Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter })) {
            [void] $K32::QueryDosDevice($Vol.DriveLetter,$StrBld,65536)
            $Ntp = [regex]::Escape($StrBld.ToString())
            $String | Where-Object { $_ -match $Ntp } | ForEach-Object {
                $_ -replace $Ntp, $Vol.DriveLetter
            }
        }
    } else {
        $String
    }
}
function Invoke-Falcon ([object] $Param) {
    if (!$Param.Method) { $Param['Method'] = 'GET' }
    if (!$Param.Headers) { $Param['Headers'] = @{ Accept = 'application/json' }}
    if ((!$Falcon.Expiration -or $Falcon.Expiration -le (Get-Date).AddSeconds(600)) -and
    $Param.Uri -ne '/oauth2/token') {
        Invoke-Falcon @{ Uri = '/oauth2/token'; Method = 'POST'; Headers = @{ Accept = 'application/json';
        'Content-Type' = 'application/x-www-form-urlencoded' }; Body = $Falcon.ApiClient } | ForEach-Object {
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
    ($Param.Headers).GetEnumerator().foreach{ $Falcon.WebClient.Headers.Add($_.Key, $_.Value) }
    if ($Param.Method -eq 'GET' -and $Param.Outfile) {
        $Falcon.WebClient.DownloadFile($Param.Uri, $Param.Outfile)
    } elseif ($Param.Method -eq 'POST' -and $Param.File) {
        if ((Test-Path $Param.File -PathType Leaf) -eq $false) {
            throw "'$($Param.File)' can not be found or is not a file."
        }
        $ByteContent = Get-Content -Path $Param.File -Encoding Byte -Raw
        [System.Text.Encoding]::UTF8.GetString($Falcon.WebClient.UploadData($Param.Uri, $ByteContent))
    } elseif ($Param.Method -eq 'POST' -and $Param.Body) {
        $Falcon.WebClient.UploadString($Param.Uri, $Param.Body)
    } else {
        $Request = $Falcon.WebClient.OpenRead($Param.Uri)
        $Stream = New-Object System.IO.StreamReader $Request
        $Stream.ReadToEnd()
        @($Request, $Stream).Where({ $_ }).foreach{ $_.Dispose() }
    }
    if ($Param.Headers) {
        ($Param.Headers.Keys).Where({ $Falcon.WebClient.Headers.Get($_) }).foreach{
            $Falcon.WebClient.Headers.Remove($_)
        }
    }
    if ($Falcon.WebClient.ResponseHeaders.Get('X-Ratelimit-RetryAfter')) {
        $RetryAfter = ([System.DateTimeOffset]::FromUnixTimeSeconds($Falcon.WebClient.ResponseHeaders.Get(
            'X-Ratelimit-RetryAfter'))).Second
        Start-Sleep -Seconds $RetryAfter
        Invoke-Falcon $Param
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
if (!($PSVersionTable.CLRVersion.ToString() -ge 3.5)) { throw '.NET Framework 3.5 or newer is required' }
if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { throw $_ }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$File = Confirm-FilePath $Param.File
if ((Test-Path $File) -eq $false) {
    throw "Cannot find path '$File' because it does not exist."
} elseif ((Test-Path $File -PathType Leaf) -eq $false) {
    throw "'File' must be a file."
}
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
$Falcon = @{
    ApiClient = "client_id=$($Param.ClientId)&client_secret=$($Param.ClientSecret)"
    WebClient = New-Object System.Net.WebClient
}
if ($Param.MemberCid) {
    $Falcon.ApiClient += "&member_cid=$($Param.MemberCid)"
}
$Falcon.WebClient.BaseAddress = $Param.Hostname
$Falcon.WebClient.Encoding = [System.Text.Encoding]::UTF8
$EnvId = if ((Get-WmiObject -Class Win32_OperatingSystem).Caption -match 'Windows 10') {
    160
} elseif ([Environment]::Is64BitOperatingSystem -eq $true) {
    110
} else {
    100
}
$Comment = "$($env:COMPUTERNAME)_$((Get-Date).ToFileTimeUtc())"
$Sample = Invoke-Falcon @{ Uri = "/samples/entities/samples/v3?file_name=$($File |
    Split-Path -Leaf)&comment=$Comment"; Method = 'POST'; Headers = @{ Accept = 'application/json';
    'Content-Type' = 'application/octet-stream' }; File = $File }
$Sha256 = [regex]::Matches($Sample,'"sha256": "(?<sha256>\w{64})",?')[0].Groups['sha256'].Value
if (!$Sample -or !$Sha256) {
    throw 'Failed sample upload.'
}
$Submit = Invoke-Falcon @{ Uri = '/falconx/entities/submissions/v1'; Method = 'POST'; Headers = @{ Accept =
    'application/json'; 'Content-Type' = 'application/json' }; Body = '{"sandbox":[{"environment_id":' + $EnvId +
    ',"sha256":"' + $Sha256 + '","submit_name":"' + $Comment + '"}]}' }
if (!$Submit) {
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
Write-Output $Output $Param "submit_sandbox_$((Get-Date).ToFileTimeUtc()).json"