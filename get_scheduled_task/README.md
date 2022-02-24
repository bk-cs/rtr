## DESCRIPTION
List scheduled tasks

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_scheduled_task" -CommandLine=```'{"Filter":"Example"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Filter = 'Example' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_scheduled_task' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
