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
        { !$_.Message } { throw "Missing required parameter 'Message'." }
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
            ConvertTo-Json @($B) -Depth 8 >> (Join-Path $Rtr $Json)
        }
    }
}
$Param = parse $args[0]
$Def = @"
using System;
using System.Runtime.InteropServices;

public class WTSMessage {
[DllImport("wtsapi32.dll", SetLastError = true)]
public static extern bool WTSSendMessage(
IntPtr hServer,
[MarshalAs(UnmanagedType.I4)] int SessionId,
String pTitle,
[MarshalAs(UnmanagedType.U4)] int TitleLength,
String pMessage,
[MarshalAs(UnmanagedType.U4)] int MessageLength,
[MarshalAs(UnmanagedType.U4)] int Style,
[MarshalAs(UnmanagedType.U4)] int Timeout,
[MarshalAs(UnmanagedType.U4)] out int pResponse,
bool bWait
);

static int response = 0;

public static int SendMessage(int SessionID, String Title, String Message, int Timeout, int MessageBoxType) {
WTSSendMessage(IntPtr.Zero, SessionID, Title, Title.Length, Message, Message.Length, MessageBoxType, Timeout, out response, true);

return response;
}
}
"@
if (!([System.Management.Automation.PSTypeName]'WTSMessage').Type) { Add-Type -TypeDefinition $Def }
$Out = Get-Process -IncludeUserName | Where-Object { $_.SessionId -ne 0 } | Select-Object SessionId, UserName |
Sort-Object -Unique | ForEach-Object {
    $Result = if ($_.SessionId) {
        [WTSMessage]::SendMessage($_.SessionId,'CrowdStrike Falcon',$Param.Message,15,0x00000040L)
    } else {
        'no_active_session'
    }
    [PSCustomObject]@{ Username = $_.UserName; Message  = if ($Result -eq 1) { $Param.Message } else { $Result }}
}
shumio 'send_message.ps1' $Out $Humio.Cloud $Humio.Token
$Out | ConvertTo-Json -Compress