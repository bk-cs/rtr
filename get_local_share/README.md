## DESCRIPTION
List local-hosted file shares

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_local_share" -CommandLine=```'{"Log":true}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Log = $true } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_local_share' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
