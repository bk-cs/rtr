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
function parse ([string] $String) {
    $Param = try { $String | ConvertFrom-Json } catch { throw $_ }
    switch ($Param) {
        { -not $_.File } {
            throw "Missing required parameter 'File'."
        }
        { $_.File } {
            $_.File = validate $_.File
            if ((Test-Path $_.File -PathType Leaf) -eq $false) {
                throw "Cannot find path '$($_.File)' because it does not exist or is not a file."
            }
        }
    }
    $Param
}
$Param = if ($args[0]) { parse $args[0] }
$Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
if ((Test-Path $Rtr) -eq $false) { ni $Rtr -ItemType Directory }
$StdOut = Join-Path $Rtr "run_cli_tool_$((Get-Date).ToFileTimeUtc()).stdout.log"
$StdErr = Join-Path $Rtr "run_cli_tool_$((Get-Date).ToFileTimeUtc()).stderr.log"
$Start = @{ FilePath = $Param.File; RedirectStandardOutput = $StdOut; RedirectStandardError = $StdErr }
if ($Param.ArgumentList) { $Start['ArgumentList'] = $Param.ArgumentList }
start @Start -PassThru | % {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Output',$Rtr)))
    if ($Param.Delete -eq $true) {
        $Wait = @{ FilePath = 'powershell.exe'; ArgumentList = "-Command &{ Wait-Process $(
            $_.Id); sleep 10; rm $($Param.File) -Force }" }
        [void] (start @Wait -PassThru)
    }
    $_ | select Id, ProcessName, Output | ConvertTo-Json -Compress
}