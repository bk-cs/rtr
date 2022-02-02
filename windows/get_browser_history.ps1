$Param = if ($args[0]) { $args[0] | ConvertFrom-Json }
$Json = "get_browser_history_$((Get-Date).ToFileTimeUtc()).json"
$Output = foreach ($User in (Get-WmiObject Win32_UserProfile | Where-Object {
$_.localpath -notmatch 'Windows' }).localpath) {
    foreach ($Path in @('AppData\Local\Google\Chrome\User Data\Default\History',
    'AppData\Local\Microsoft\Edge\User Data\Default\History')) {
        $History = Join-Path $User $Path
        if (Test-Path $History) {
            $Domain = '(htt(p|ps))://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'
            Get-Content $History | Select-String -AllMatches $Domain |
            ForEach-Object { ($_.Matches).Value } | Sort-Object -Unique | ForEach-Object {
                if ($_ -match $Search) {
                    [PSCustomObject] @{
                        Username = $User | Split-Path -Leaf
                        Browser  = if ($History -match 'Chrome') { 'Chrome' } else { 'Edge' }
                        Domain   = $_
                    }
                }
            }
        }
    }
}
if ($Param.Filter) {
    $Output = $Output | Where-Object { $_.Domain -match $Param.Filter }
}
if ($Output -and $Param.Log -eq $true) {
    $Rtr = Join-Path $env:SystemRoot 'system32\drivers\CrowdStrike\Rtr'
    if ((Test-Path $Rtr) -eq $false) { New-Item $Rtr -ItemType Directory }
    $Output | ForEach-Object { $_ | ConvertTo-Json -Compress >> "$Rtr\$Json" }
}
$Output | ForEach-Object { $_ | ConvertTo-Json -Compress }