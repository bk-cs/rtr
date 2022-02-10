## DESCRIPTION
List user(s) that are currently logged in

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_current_user" -CommandLine=```'{"Log":true}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Log = $true } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_current_user' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
