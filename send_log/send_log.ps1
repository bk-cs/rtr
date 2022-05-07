$Humio = @{ Cloud = ''; Token = '' }
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
function shumio ([string]$Script,[object[]]$Object,[string]$Cloud,[string]$Token) {
    if ($Object -and $Cloud -and $Token) {
        $Iwr = @{ Uri = $Cloud,'api/v1/ingest/humio-structured/' -join $null; Method = 'post';
            Headers = @{ Authorization = 'Bearer',$Token -join ' '; ContentType = 'application/json' }}
        $Att = @{ host = [System.Net.Dns]::GetHostName(); script = $Script }
        $Reg = reg query 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CSAgent\Sim' 2>$null
        if ($Reg) {
            $Att['cid'] = (($Reg -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
            $Att['aid'] = (($Reg -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
        }
        [object[]]$Event = @($Object).foreach{
            if ($_ -is [PSCustomObject]) {
                $Clone = $Att.Clone()
                @($_.PSObject.Properties).foreach{ $Clone[$_.Name]=$_.Value }
                ,@{ timestamp = Get-Date -Format o; attributes = $Clone }
            } else {
                ,@{ timestamp = Get-Date -Format o; attributes = $Att; rawstring = [string]$_ }
            }
        }
        if ($Event) {
            $Body = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @($Event) }
            try {
                Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($Body) -Depth 8) -UseBasicParsing
            } catch {}
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
[scriptblock]$WaitScript = {
    param([string]$File,[string]$Cloud,[string]$Token)
    function shumio ([string]$Script,[object[]]$Object,[string]$Cloud,[string]$Token) {
        if ($Object -and $Cloud -and $Token) {
            $Iwr = @{ Uri = $Cloud,'api/v1/ingest/humio-structured/' -join $null; Method = 'post';
                Headers = @{ Authorization = 'Bearer',$Token -join ' '; ContentType = 'application/json' }}
            $Att = @{ host = [System.Net.Dns]::GetHostName(); script = $Script }
            $Reg = reg query 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CSAgent\Sim' 2>$null
            if ($Reg) {
                $Att['cid'] = (($Reg -match 'CU ') -split 'REG_BINARY')[-1].Trim().ToLower()
                $Att['aid'] = (($Reg -match 'AG ') -split 'REG_BINARY')[-1].Trim().ToLower()
            }
            [object[]]$Event = @($Object).foreach{
                if ($_ -is [PSCustomObject]) {
                    $Clone = $Att.Clone()
                    @($_.PSObject.Properties).foreach{ $Clone[$_.Name]=$_.Value }
                    ,@{ timestamp = Get-Date -Format o; attributes = $Clone }
                } else {
                    ,@{ timestamp = Get-Date -Format o; attributes = $Att; rawstring = [string]$_ }
                }
            }
            if ($Event) {
                $Body = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @($Event) }
                try {
                    Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($Body) -Depth 8) -UseBasicParsing
                } catch {}
            }
        }
    }
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
        [object[]]$Object = if ($File -match '\.csv$') {
            try { Get-Content $File | ConvertFrom-Csv } catch {}
        } elseif ($File -match '\.json$') {
            try { Get-Content $File | ConvertFrom-Json } catch {}
        } else {
            try { (Get-Content $File).Normalize() } catch {}
        }
        if ($Object) {
            $Req = shumio 'send_log.ps1' $Object $Cloud $Token
            if ($Req -and $Req.StatusCode -eq 200) { Remove-Item $File }
        }
    }
}
$Param = parse $args[0]
[System.Collections.Generic.List[string]]$Wait = @()
[System.Collections.Generic.List[object]]$Out = @()
foreach ($i in $Param.File) {
    try {
        $Open = [System.IO.File]::Open($i,'Open','Write')
        $Open.Close()
        $Open.Dispose()
        $Out.Add(@{ File = $i; Sent = $false; Deleted = $false; Status = $null })
    } catch {
        $Wait.Add($i)
    }
}
@($Out).foreach{
    [object[]]$Object = if ($_.File -match '\.csv$') {
        try { Get-Content $_.File | ConvertFrom-Csv } catch {}
    } elseif ($_.File -match '\.json$') {
        try { Get-Content $_.File | ConvertFrom-Json } catch {}
    } else {
        try { (Get-Content $_.File).Normalize() } catch {}
    }
    if ($Object) {
        $Req = shumio 'send_log.ps1' $Object $Humio.Cloud $Humio.Token
        if ($Req -and $Req.StatusCode -eq 200) {
            Remove-Item $_.File
            $_.Status = $Req.StatusCode
            $_.Sent = $true
            $_.Deleted = if ((Test-Path $_.File) -eq $true) { $false } else { $true }
        }
    } else {
        $_.Status = 'failed_to_ingest'
    }
}
foreach ($i in $Wait) {
    $ArgList = '-Command &{',$WaitScript,'}',("'$i'"),$Humio.Cloud,$Humio.Token -join ' '
    @(Start-Process powershell.exe $ArgList -PassThru).foreach{
        $Out.Add(@{
            File = $i
            Sent = $false
            Deleted = $false
            Status = 'waiting_to_access'
        })
    }
}
@($Out).foreach{ $_ | ConvertTo-Json -Compress }