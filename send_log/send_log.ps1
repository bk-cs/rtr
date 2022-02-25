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
    [System.Collections.ArrayList] $Wait = @()
    [System.Collections.ArrayList] $Out = @()
    foreach ($File in $Arr) {
        try { $Open = [System.IO.File]::Open($File,'Open','Write'); $Open.Close(); $Open.Dispose() }
        catch { [void] $Wait.Add($File) }
    }
    foreach ($File in ($Arr | ? { $Wait -notcontains $_ })) {
        $Iwr = @{ Uri = @($Cloud, 'api/v1/ingest/humio-structured/') -join $null; Method = 'post'; Headers = @{
            Authorization = @('Bearer', $Token) -join ' '; ContentType = 'application/json' }}
        $Obj = if ($File -match '\.csv$') {
            try { ipcsv $File } catch {}
        } elseif ($File -match '\.json$') {
            try { gc $File | ConvertFrom-Json } catch {}
        } elseif ($File -match '\.(log|txt)$') {
            try { (gc $File).Normalize() } catch {}
        }
        $Res = [PSCustomObject] @{ File = $File; Sent = $false; Deleted = $false; Status = '' }
        $Req = if ($Obj -is [PSCustomObject] -and $Obj.tags -and $Obj.events) {
            iwr @Iwr -Body (ConvertTo-Json @($Obj) -Depth 8 -Compress) -UseBasicParsing
        } elseif ($Obj) {
            $A = @{ script = 'send_log.ps1'; file = $File }
            $R = reg query ('HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e04' +
                '23f-7058-48c9-a204-725362b67639}\Default') 2>$null
            if ($R) {
                $A['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
                $A['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
            }
            if ($Obj -is [string] -and ($Obj | measure).Count -eq 1) {
                $E = @{ timestamp = Get-Date -Format o; attributes = $A; rawstring = $Obj }
                $B = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @($E) }
                iwr @Iwr -Body (ConvertTo-Json @($B) -Depth 8 -Compress) -UseBasicParsing
            } else {
                $E = if ($Obj -is [PSCustomObject]) {
                    $Obj | % {
                        $C = $A.Clone(); $_.PSObject.Properties | % { $C[$_.Name]=$_.Value }
                        ,@{ timestamp = Get-Date -Format o; attributes = $C }
                    }
                } else {
                    $Obj | % { ,@{ timestamp = Get-Date -Format o; attributes = $A; rawstring = $_ }}
                }
                for ($i = 0; $i -lt ($E | measure).Count; $i += 200) {
                    $B = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @($E[$i..($i + 199)]) }
                    iwr @Iwr -Body (ConvertTo-Json @($B) -Depth 8 -Compress) -UseBasicParsing
                }
            }
        } else {
            $Res.Status = 'failed_to_ingest'
        }
        if ($Req) {
            $Res.Status = ($Req.StatusCode | sort -Unique) -join ', '
            if ($Res.Status -eq 200) {
                $Res.Sent = $true; rm $File
                $Res.Deleted = if ((Test-Path $File) -eq $false) { $true } else { $false }
            }
        } else {
            $Res.Status = 'failed_to_send'
        }
        [void] $Out.Add($Res)
    }
    if ($Wait) {
        [scriptblock] $Scr = {
            param([string] $Cloud, [string] $Token, [string] $File)
            $Iwr = @{ Uri = @($Cloud, 'api/v1/ingest/humio-structured/') -join $null; Method = 'post'; Headers = @{
                Authorization = @('Bearer', $Token) -join ' '; ContentType = 'application/json' }}
            $i = 0
            do {
                $Unl = try {
                    sleep 30
                    $Open = [System.IO.File]::Open($File,'Open','Write'); $Open.Close(); $Open.Dispose()
                    $true
                } catch {
                    $false
                }
                $i += 30
            } until ( $Unl -eq $true -or $i -ge 600 )
            if ($Unl -eq $true) {
                $Obj = if ($File -match '\.csv$') {
                    try { ipcsv $File } catch {}
                } elseif ($File -match '\.json$') {
                    try { gc $File | ConvertFrom-Json } catch {}
                } elseif ($File -match '\.(log|txt)$') {
                    try { (gc $File).Normalize() } catch {}
                }
                $Req = if ($Obj -is [PSCustomObject] -and $Obj.tags -and $Obj.events) {
                    iwr @Iwr -Body (ConvertTo-Json @($Obj) -Depth 8 -Compress) -UseBasicParsing
                } elseif ($Obj) {
                    $A = @{ script = 'send_log.ps1'; file = $File }
                    $R = reg query ('HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d' +
                        '}\{16e0423f-7058-48c9-a204-725362b67639}\Default') 2>$null
                    if ($R) {
                        $A['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
                        $A['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
                    }
                    $E = if ($Obj -is [PSCustomObject]) {
                        $Obj | % {
                            $C = $A.Clone()
                            $_.PSObject.Properties | % { $C[$_.Name]=$_.Value }
                            ,@{ timestamp = Get-Date -Format o; attributes = $C }
                        }
                    } else {
                        if (($Obj | measure).Count -eq 1) {
                            ,@{ timestamp = Get-Date -Format o; attributes = $A; rawstring = $Obj }
                        } elseif (($Obj | measure).Count -gt 1) {
                            $Obj | ? { -not [string]::IsNullOrEmpty($_) } | % {
                                ,@{ timestamp = Get-Date -Format o; attributes = $A; rawstring = $_ }
                            }
                        }
                    }
                    for ($i = 0; $i -lt ($E | measure).Count; $i += 200) {
                        $B = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @($E[$i..($i + 199)]) }
                        iwr @Iwr -Body (ConvertTo-Json @($B) -Depth 8 -Compress) -UseBasicParsing
                    }
                }
                if ($Req -and (($Req.StatusCode | sort -Unique) -join ', ') -eq 200) { rm $File }
            }
        }
        foreach ($File in $Wait) {
            $ArgList = @('-Command &{', $Scr, '}', $Cloud, $Token, ('"' + $File + '"')) -join ' '
            start powershell.exe $ArgList -PassThru | % {
                $Res = [PSCustomObject] @{ File = $File; Sent = $false; Deleted = $false;
                    Status = 'waiting_to_access' }
                [void] $Out.Add($Res)
            }
        }
    }
    $Out | ConvertTo-Json -Compress
}
function parse ([string] $String) {
    $Param = try { $String | ConvertFrom-Json } catch { throw $_ }
    switch ($Param) {
        { $_.File } {
            $_.File = validate $_.File
            if ((Test-Path $_.File -PathType Leaf) -eq $false) {
                throw "Cannot find path '$($_.File)' because it does not exist or is not a file."
            }
        }
        { -not $_.File } {
            $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
            [array] $Arr = @('*.csv','*.json','*.log','*.txt').foreach{ (gci $Rtr $_ -File -EA 0).FullName } |
                sort -Unique
            if ($Arr) {
                $_.PSObject.Properties.Add((New-Object PSNoteProperty('File',$Arr)))
            } else {
                throw "No file specified and no compatible files found in '$Rtr'."
            }
        }
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
shumio $Param.Cloud $Param.Token $Param.File