## DESCRIPTION
List local administrators

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

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
