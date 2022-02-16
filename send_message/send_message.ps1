function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.elog -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
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
if (!([System.Management.Automation.PSTypeName]'WTSMessage').Type) {
    Add-Type -TypeDefinition $Def
}
$Message = $(if ($Param.cuser) { $Param.cuser + "`n`n" }) + $Param.bmessage + $(if ($Param.dcontact) { "`n`nPlease reach out to " + $Param.dcontact  })

$UserLogged = $false
$UserLogged = Get-Process -IncludeUserName | Where-Object { $_.SessionId -ne 0 } | Select-Object SessionId, UserName |
Sort-Object -Unique | ForEach-Object { if ($_.UserName -match $Param.cuser) { $true } }

$Output = [PSCustomObject] @{
            Delivered = $false
        }

$Output = Get-Process -IncludeUserName | Where-Object { $_.SessionId -ne 0 } | Select-Object SessionId, UserName |
Sort-Object -Unique | ForEach-Object {
    if ( $UserLogged ) {
        $Result = if ($_.SessionId -and ($_.UserName -match $Param.cuser) ) {
            [WTSMessage]::SendMessage($_.SessionId,$Param.atitle,$Message,15,0x00000040L)
        }
        [PSCustomObject] @{
            Delivered = $true
            Username = $_.UserName
            Message  = if ($Result -eq 1) { $Param.bmessage } else { $Result }
        }
    }
}

Write-Output $Output $Param "send_message_$((Get-Date).ToFileTimeUtc()).json" 
