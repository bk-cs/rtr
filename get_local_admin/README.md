## DESCRIPTION
List local administrators

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_local_admin" -CommandLine=```'{"Filter":"Username"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Filter = 'Username' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='local_admin' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
