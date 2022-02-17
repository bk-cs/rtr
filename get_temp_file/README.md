## SYNOPSIS
List temporary files

## PARAMETER Username
Filter to temporary files for a specific user. If left unspecified, temporary files from the system and
all user directories will be listed.

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_temp_file" -CommandLine=```'{"Username":"IEUser","Log":true}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Log = $true } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_temp_file' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
