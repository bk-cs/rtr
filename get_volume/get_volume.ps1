function Write-Output ([object] $Object, [object] $Param, [string] $Json) {
    if ($Object -and $Param.Log -eq $true) {
        $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
        if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
        $Object | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
    }
    $Object | ForEach-Object { $_ | ConvertTo-Json -Compress }
}
$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Def = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint QueryDosDevice(
    string lpDeviceName,
    System.Text.StringBuilder lpTargetPath,
    uint ucchMax);
'@
$StrBld = New-Object System.Text.StringBuilder(65535)
$K32 = Add-Type -MemberDefinition $Def -Name Kernel32 -Namespace Win32 -PassThru
$Output = Get-Volume -EA 0 | Where-Object { $_.DriveLetter } | Select-Object DriveLetter, FileSystemLabel,
FileSystem, SizeRemaining | ForEach-Object {
    [void] $K32::QueryDosDevice("$($_.DriveLetter):",$StrBld,65535)
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('NtPath',$StrBld.ToString())))
    $_
}
Write-Output $Output $Param "get_volume_$((Get-Date).ToFileTimeUtc()).json"