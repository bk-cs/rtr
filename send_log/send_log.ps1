$Humio = @{ Cloud = 'https://cloud.community.humio.com'; Token = '76c5ebe9-8e68-4f03-a2fb-de10d933215f' }
switch ($Humio) {
    { $_.Cloud -and $_.Cloud -notmatch '/$' } { $_.Cloud += '/' }
    { ($_.Cloud -and !$_.Token) -or ($_.Token -and !$_.Cloud) -or (!$_.Token -and !$_.Cloud) } {
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
function validate ([string]$Str) {
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
            foreach ($Vol in (Get-CimInstance Win32_Volume | Where-Object { $_.DriveLetter })) {
                [void]$K32::QueryDosDevice($Vol.DriveLetter,$StrBld,65536)
                $Ntp = [regex]::Escape($StrBld.ToString())
                $Str | Where-Object { $_ -match $Ntp } | ForEach-Object { $_ -replace $Ntp, $Vol.DriveLetter }
            }
        }
        else { $Str }
    }
}
function shumio ([string]$Cloud,[string]$Token,[object[]]$File) {
    [System.Collections.Generic.List[string]]$Wait = @()
    [System.Collections.Generic.List[object]]$Out = @()
    foreach ($f in $File) {
        try {
            $Open = [System.IO.File]::Open($f,'Open','Write')
            $Open.Close()
            $Open.Dispose()
        } catch {
            $Wait.Add($f)
        }
    }
    foreach ($f in ($File | Where-Object { $Wait -notcontains $_ })) {
        $Res = [PSCustomObject]@{ File = $f; Sent = $false; Deleted = $false; Status = '' }
        $Iwr = @{ Uri = $Cloud,'api/v1/ingest/humio-structured/' -join $null; Method = 'post';
            Headers = @{ Authorization = 'Bearer',$Token -join ' '; ContentType = 'application/json' }}
        [string[]]$Text = try { (Get-Content $f).Normalize() } catch {}
        if ($Text) {
            $A = @{ host = [System.Net.Dns]::GetHostName(); script = 'send_log.ps1'; file = $f }
            $R = reg query 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CSAgent\Sim' 2>$null
            if ($R) {
                $A['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
                $A['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
            }
            [object[]]$Json = try { $Text | ConvertFrom-Json } catch {}
            [object[]]$Csv = try { $Text | ConvertFrom-Csv } catch {}
            [object[]]$E = if ($Json) {
                $Fields = @($Json).foreach{ $_.PSObject.Properties.Name } | Select-Object -Unique
                if (($Fields | Measure-Object).Count -eq 2 -and $Fields -contains 'tags' -and
                $Fields -contains 'events') {
                    $Req = Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($Json) -Depth 8) -UseBasicParsing
                } else {
                    @($Json).foreach{
                        $C = $A.Clone()
                        @($_.PSObject.Properties).foreach{ $C[$_.Name] = $_.Value }
                        ,@{ timestamp = Get-Date -Format o; attributes = $C }
                    }
                }
            } elseif ($Csv) {
                @($Csv).foreach{
                    $C = $A.Clone()
                    @($_.PSObject.Properties).foreach{ $C[$_.Name] = $_.Value }
                    ,@{ timestamp = Get-Date -Format o; attributes = $C }
                }
            } else {
                @($Text | Where-Object { ![string]::IsNullOrEmpty($_) }).foreach{
                    ,@{ timestamp = Get-Date -Format o; attributes = $A; rawstring = $_ }
                }
            }
            if ($E) {
                $B = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @($E) }
                $Req = Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($B) -Depth 8) -UseBasicParsing
            }
            if (!$Req -or $Req.StatusCode -ne 200) {
                $Res.Status = 'failed_to_send'
            } else {
                $Res.Status = $Req.StatusCode
                $Res.Sent = $true
                if ((Test-Path $f) -eq $true) { Remove-Item $f }
                $Res.Deleted = if ((Test-Path $f) -eq $false) { $true } else { $false }
            }
        } else {
            $Res.Status = 'failed_to_ingest'
        }
        $Out.Add($Res)
    }
    if ($Wait) {
        [scriptblock]$Scr = {
            param([string]$Cloud,[string]$Token,[string]$File)
            $Iwr = @{ Uri = $Cloud,'api/v1/ingest/humio-structured/' -join $null; Method = 'post';
                Headers = @{ Authorization = 'Bearer',$Token -join ' '; ContentType = 'application/json' }}
            $i = 0
            do {
                $Unl = try {
                    Start-Sleep 30
                    $Open = [System.IO.File]::Open($File,'Open','Write')
                    $Open.Close()
                    $Open.Dispose()
                    $true
                } catch {
                    $false
                }
                $i += 30
            } until ( $Unl -eq $true -or $i -ge 600 )
            if ($Unl -eq $true) {
                [string[]]$Text = try { (Get-Content $File).Normalize() } catch {}
                if ($Text) {
                    $A = @{ host = [System.Net.Dns]::GetHostName(); script = 'send_log.ps1'; file = $f }
                    $R = reg query 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CSAgent\Sim' 2>$null
                    if ($R) {
                        $A['cid'] = (($R -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
                        $A['aid'] = (($R -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
                    }
                    [object[]]$Json = try { $Text | ConvertFrom-Json } catch {}
                    [object[]]$Csv = try { $Text | ConvertFrom-Csv } catch {}
                    [object[]]$E = if ($Json) {
                        $Fields = @($Json).foreach{ $_.PSObject.Properties.Name } | Select-Object -Unique
                        if (($Fields | Measure-Object).Count -eq 2 -and $Fields -contains 'tags' -and
                        $Fields -contains 'events') {
                            $Req = Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($Json) -Depth 8) -UseBasicParsing
                        } else {
                            @($Json).foreach{
                                $C = $A.Clone()
                                @($_.PSObject.Properties).foreach{ $C[$_.Name] = $_.Value }
                                ,@{ timestamp = Get-Date -Format o; attributes = $C }
                            }
                        }
                    } elseif ($Csv) {
                        @($Csv).foreach{
                            $C = $A.Clone()
                            @($_.PSObject.Properties).foreach{ $C[$_.Name] = $_.Value }
                            ,@{ timestamp = Get-Date -Format o; attributes = $C }
                        }
                    } else {
                        @($Text | Where-Object { ![string]::IsNullOrEmpty($_) }).foreach{
                            ,@{ timestamp = Get-Date -Format o; attributes = $A; rawstring = $_ }
                        }
                    }
                    if ($E) {
                        $B = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @($E) }
                        $Req = Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($B) -Depth 8) -UseBasicParsing
                    }
                    if ($Req -and $Req.StatusCode -eq 200) {
                        if ((Test-Path $File) -eq $true) { Remove-Item $File }
                    }
                }
            }
        }
        foreach ($f in $Wait) {
            $ArgList = '-Command &{',$Scr,'}',$Cloud,$Token,('"' + $f + '"') -join ' '
            @(Start-Process powershell.exe $ArgList -PassThru).foreach{
                $Out.Add([PSCustomObject]@{
                    File = $f
                    Sent = $false
                    Deleted = $false
                    Status = 'waiting_to_access'
                })
            }
        }
    }
    $Out | ConvertTo-Json -Compress
}
function parse ([string]$Inputs) {
    $Param = if ($Inputs) { try { $Inputs | ConvertFrom-Json } catch { throw $_ }} else { [PSCustomObject]@{} }
    switch ($Param) {
        { $_.File } {
            $_.File = validate $_.File
            if ((Test-Path $_.File -PathType Leaf) -eq $false) {
                throw "Cannot find path '$($_.File)' because it does not exist or is not a file."
            }
        }
        { !$_.File } {
            $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
            [string[]]$Arr = @('*.csv','*.json','*.log','*.txt').foreach{
                (Get-ChildItem $Rtr $_ -File -EA 0).FullName
            } | Sort-Object -Unique
            if ($Arr) {
                $_.PSObject.Properties.Add((New-Object PSNoteProperty('File',$Arr)))
            } else {
                throw "No file specified and no compatible files found in '$Rtr'."
            }
        }
    }
    $Param
}
$Param = parse $args[0]
shumio $Humio.Cloud $Humio.Token $Param.File