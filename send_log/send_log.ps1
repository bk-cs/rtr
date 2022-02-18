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
function shumio ([string] $Cloud, [string] $Token, [array] $Arr) {
    $Inv = @{ Uri = @($Cloud, 'api/v1/ingest/humio-structured/') -join $null; Method = 'post'; Headers = @{
        Authorization = @('Bearer', $Token) -join ' '; ContentType = 'application/json' }}
    [array] $Wait = @()
    foreach ($Obj in $Arr) {
        try { $Str = [System.IO.File]::Open($Obj,'Open','Write'); $Str.Close(); $Str.Dispose() }
        catch { $Wait += $Obj }
    }
    $Out = $Arr | ? { $Wait -notcontains $_ } | % {
        $Imp = try { gc $_ | ConvertFrom-Json } catch {}
        if (!$Imp) {
            @{ Json = $_; Sent = $false; Deleted = $false; Status = 'parse_failure' }
        } else {
            $Req = $Imp | % { iwr @Inv -Body (ConvertTo-Json @($_) -Depth 8 -Compress) -UseBasicParsing }
            if ($Req.StatusCode -ne 200) {
                @{ Json = $_; Sent = $false; Deleted = $false; Status = 'send_failure' }
            } else {
                rm $_
                if ((Test-Path $_ -PathType Leaf) -eq $false) {
                    @{ Json = $_; Sent = $true; Deleted = $true; Status = 'OK' }
                } else {
                    @{ Json = $_; Sent = $true; Deleted = $false; Status = 'delete_failure' }
                }
            }
        }
    }
    if ($Wait) {
        [scriptblock] $Scr = {
            param([string] $Cloud, [string] $Token, [array] $Arr)
            $Inv = @{ Uri = @($Cloud, 'api/v1/ingest/humio-structured/') -join $null; Method = 'post'; Headers = @{
                Authorization = @('Bearer', $Token) -join ' '; ContentType = 'application/json' }}
            foreach ($File in $Arr) {
                $i = 0
                do {
                    $Unl = try {
                        sleep 30
                        $Str = [System.IO.File]::Open($File,'Open','Write'); $Str.Close(); $Str.Dispose()
                        $true
                    } catch {
                        $false
                    }
                    $i += 30
                } until ( $Unl -eq $true -or $i -eq 600 )
                if ($Unl -eq $true) {
                    try {
                        $Imp = try { gc $File | ConvertFrom-Json } catch {}
                        if ($Imp) {
                            $Imp | % { iwr @Inv -Body (ConvertTo-Json @($_) -Depth 8 -Compress) -UseBasicParsing }
                        }
                    } catch {}
                }
            }
        }
        $Sta = @{ FilePath = 'powershell.exe'; ArgumentList = "-Command &{$Scr} '$Cloud' '$Token' '$(
            $Wait -join ', ')'"; PassThru = $true }
        $Out += start @Sta | % {
            $Wait | % { @{ Json = $_; Sent = $false; Deleted = $false; Status = 'waiting_to_access' }}
        }
    }
    $Out | ConvertTo-Json -Compress
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
@('Cloud','Token').foreach{
    if (!$Param.$_) {
        throw "Missing required parameter '$_'."
    } elseif ($_ -eq 'Cloud') {
        if ($Param.$_ -notmatch 'https://cloud(.(community|us))?.humio.com') {
            throw "'$($Param.$_)' is not a valid Humio cloud value."
        } elseif ($Param.$_ -notmatch '/$') {
            $Param.$_ += '/'
        }
    } elseif ($_ -eq 'Token' -and $Param.$_ -notmatch '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$') {
        throw "'$($Param.$_)' is not a valid ingest token."
    }
}
if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
[array] $Arr = if ($Param.Json) {
    $Param.Json | % { validate $_ }
} else {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    (gci $Rtr -Filter *.json -File -EA 0).FullName
}
if (-not $Arr) {
    throw 'No Json files found.'
}
$Arr | ? { ![string]::IsNullOrEmpty($_) } | % {
    if ((Test-Path $_ -PathType Leaf) -eq $false) {
        throw "Cannot find path '$_' because it does not exist."
    } elseif ($_ -notmatch '\.json$') {
        throw "'$_' is not a Json file."
    }
}
shumio $Param.Cloud $Param.Token $Arr