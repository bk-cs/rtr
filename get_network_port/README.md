## DESCRIPTION
Output listening TCP and UDP ports

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

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
