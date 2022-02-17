$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
$Script = {
    param($Path, $Filter, $Include, $Exclude)
    function Get-UniqueHash ([object] $Obj, [string] $Str) {
        foreach ($I in $Obj) {
            $E = ($Obj | Where-Object { $_.$Str -eq $I.$Str } | Select-Object -Unique).Sha256
            $H = if ($E) { $E } else { try { (Get-FileHash $I.$Str -EA 0).Hash.ToLower() } catch { $null }}
            $I.PSObject.Properties.Add((New-Object PSNoteProperty('Sha256',$H)))
        }
        $Obj
    }
    try {
        $Param = @{ Path = $Path; Filter = $Filter; Recurse = $true; File = $true }
        $PSBoundParameters.GetEnumerator().Where({ $Param.Keys -notcontains $_.Key }).foreach{
            $Param[$_.Key] = $_.Value
        }
        $Output = Get-ChildItem @Param -EA 0 | Select-Object FullName, CreationTime, LastWriteTime,
        LastAccessTime | ForEach-Object {
            $_.PSObject.Properties | ForEach-Object {
                if ($_.Value -is [datetime]) { $_.Value = try { $_.Value.ToFileTimeUtc() } catch { $_.Value } }
            }
            $_
        }
        Get-UniqueHash $Output FullName | ForEach-Object { $_ | ConvertTo-Json -Compress }
    } catch {
        "$(@{ message = $_ } | ConvertTo-Json -Compress)"
    }
}
if ((Test-Path $Param.Path) -eq $false) {
    throw "Cannot find path '$($Param.Path)' because it does not exist."
}
$Inputs = @($Param.PSObject.Properties.foreach{ "-$($_.Name) '$($_.Value)'" }) -join ' '
$Start = @{
    FilePath               = 'powershell.exe'
    ArgumentList           = "-Command &{$Script} $Inputs"
    RedirectStandardOutput = "$Rtr\find_file_$((Get-Date).ToFileTimeUtc()).json"
    PassThru               = $true
}
Start-Process @Start | Select-Object Id, ProcessName | ForEach-Object {
    $_.PSObject.Properties.Add((New-Object PSNoteProperty('Json',$Start.RedirectStandardOutput)))
    $_ | ConvertTo-Json -Compress
}