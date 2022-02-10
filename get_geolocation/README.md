## DESCRIPTION
Use ip-api.com to perform a geolocation request

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_geolocation" -CommandLine=```'{"Log":true}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Log = $true } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_geolocation' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
