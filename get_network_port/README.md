## DESCRIPTION
Output listening TCP and UDP ports

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_network_port" -CommandLine=```'{"Port":"^80$"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Port = '^80$' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_network_port' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
