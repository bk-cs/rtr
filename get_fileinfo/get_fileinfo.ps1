$Humio = @{ Cloud = ''; Token = '' }
switch ($Humio) {
    { $_.Cloud -and $_.Cloud -notmatch '/$' } { $_.Cloud += '/' }
    { ($_.Cloud -and !$_.Token) -or ($_.Token -and !$_.Cloud) } {
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
        { !$_.File } { throw "Missing required parameter 'File'." }
        { $_.File } {
            $_.File = validate $_.File
            if ((Test-Path $_.File -PathType Leaf) -eq $false) {
                throw "Cannot find path '$($_.File)' because it does not exist or is not a file."
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
            $Clone = $Att.Clone()
            @($_.PSObject.Properties).foreach{ $Clone[$_.Name]=$_.Value }
            ,@{ timestamp = Get-Date -Format o; attributes = $Clone }
        }
        $Req = if ($Event) {
            $Body = @{ tags = @{ source = 'crowdstrike-rtr_script' }; events = @($Event) }
            try { Invoke-WebRequest @Iwr -Body (ConvertTo-Json @($Body) -Depth 8) -UseBasicParsing } catch {}
        }
        if (!$Req -or $Req.StatusCode -ne 200) {
            $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
            $Json = $Script -replace '\.ps1',"_$((Get-Date).ToFileTimeUtc()).json"
            if ((Test-Path $Rtr -PathType Container) -eq $false) { [void](New-Item $Rtr -ItemType Directory) }
            ConvertTo-Json @($Object) -Depth 8 >> (Join-Path $Rtr $Json)
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
$Param = parse $args[0]
$Out = foreach ($i in (Get-ChildItem $Param.File | Select-Object Length,CreationTime,LastWriteTime,LastAccessTime,
Mode,VersionInfo)) {
    foreach ($T in @('CreationTime','LastWriteTime','LastAccessTime')) {
        if ($i.$T) { $i.$T = $i.$T.ToFileTimeUtc() }
    }
    foreach ($P in ($i.VersionInfo | Select-Object OriginalFilename,FileDescription,ProductName,CompanyName,
    FileName,FileVersion)) {
        @($P.PSObject.Properties).Where({ $_.Value }).foreach{
            $i.PSObject.Properties.Add((New-Object PSNoteProperty($_.Name,$_.Value)))
        }
    }
    $i.PSObject.Properties.Remove('VersionInfo')
    if ($i.FileName) {
        @(Get-Content $i.FileName -Stream Zone.Identifier -EA 0 | Select-String -Pattern '=').Where({ $_ -match
        '(ZoneId|HostUrl)' }).foreach{
            [string[]]$A = $_ -split '='
            $i.PSObject.Properties.Add((New-Object PSNoteProperty($A[0],$A[1])))
        }
        $i.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',(Get-FileHash $i.FileName).Hash.ToLower())))
    }
    $i
}
shumio 'get_fileinfo.ps1' $Out $Humio.Cloud $Humio.Token
$Out | ConvertTo-Json -Compress