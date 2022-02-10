## DESCRIPTION
List motherboard information

## PARAMETER Log
Save results within a Json file in the Rtr directory (Optional)

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_baseboard" -CommandLine=```'{"Log":true}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Log = $true } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_baseboard' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
