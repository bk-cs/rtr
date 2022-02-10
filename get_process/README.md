## DESCRIPTION
List running processes

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_process" -CommandLine=```'{"Filter":"svchost"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Filter = 'svchost' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_process' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
