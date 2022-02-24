[scriptblock] $Script = {
    param([string] $Username, [string] $Cloud, [string] $Token)
    function hash ([object] $Obj, [string] $Str) {
        foreach ($I in $Obj) {
            $E = ($Obj | ? { $_.$Str -eq $I.$Str } | select -Unique).Sha256
            $H = if ($E) { $E } else { try { (Get-FileHash $I.$Str -EA 0).Hash.ToLower() } catch { $null }}
            $I.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',$H)))
        }
        $Obj
    }
    function output ([object] $Obj, [string] $Script, [string] $Cloud, [string] $Token) {
        if (-not $Obj) {
            $Obj = @{ error = 'no_results' }
        }
        if ($Cloud -and $Token) {
            $Iwr = @{ Uri = @($Cloud, 'api/v1/ingest/humio-structured/') -join $null; Method = 'post';
                Headers = @{ Authorization = @('Bearer', $Token) -join ' '; ContentType = 'application/json' }}
        }
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr -PathType Container) -eq $false) { ni $Rtr -ItemType Directory }
        $Json = $Script -replace '\.ps1', ('_' + [string] (Get-Date).ToFileTimeUtc() + '.json')
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
            $B = @{ tags = @{ type = 'crowdstrike_falcon_rtr_script' }; events = @($E[$i..($i + 199)]) }
            $Req = try { iwr @Iwr -Body (ConvertTo-Json @($B) -Depth 8 -Compress) -UseBasicParsing
            } catch { $null }
            if ($Req.StatusCode -ne 200) { ConvertTo-Json @($B) -Depth 8 -Compress >> (Join-Path $Rtr $Json) }
        }
    }
    [array] $Dir = if ($Username) {
        $Username
    } else {
        (gwmi win32_userprofile | ? { $_.SID -match '^S-1-5-21' }).LocalPath | % {
            Join-Path $_ 'Appdata\Local\Temp' }
        Join-Path $env:SystemRoot 'Temp'
    }
    $Out = $Dir.foreach{
        $Sel = @('FullName','Length','CreationTime','LastWriteTime','LastAccessTime')
        gci $_ -Recurse -File -EA 0 | select $Sel | % {
            $_.PSObject.Properties | % {
                if ($_.Value -is [datetime]) { $_.Value = try { $_.Value.ToFileTimeUtc() } catch { $_.Value }}
            }
            $_
        }
    }
    $Out = hash $Out FullName
    output $Out 'get_temp_file.ps1' $Cloud $Token
}
function parse ([string] $String) {
    $Param = try { $String | ConvertFrom-Json } catch { throw $_ }
    switch ($Param) {
        { $_.Username } {
            $UserDir = (gwmi win32_userprofile | ? { $_.LocalPath -match "$(
                [regex]::Escape($Param.Username))$" }).LocalPath
            if (-not $UserDir) {
                throw "No username found matching '$($_.Username)'."
            }
            $_.Username = $UserDir
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
$Inputs = @($Param.PSObject.Properties.foreach{ "-$($_.Name) '$($_.Value)'" }) -join ' '
$Start = @{ FilePath = 'powershell.exe'; ArgumentList = "-Command &{$Script} $Inputs" }
start @Start -PassThru | select Id, ProcessName | % {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Output',
        (Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'))))
    $_ | ConvertTo-Json -Compress
}