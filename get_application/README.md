## DESCRIPTION
List installed applications

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_application" -CommandLine=```'{"Filter":"CrowdStrike"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Filter = 'CrowdStrike' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_application' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
