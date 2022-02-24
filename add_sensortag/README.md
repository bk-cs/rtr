## DESCRIPTION
Add 'SensorGroupingTag' values

## PARAMETER SensorTag
One or more SensorTag values (Required)

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="add_sensortag" -CommandLine=```'{"SensorTag":["my","example","tags"]}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ SensorTag = @('my','example','tags') } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='add_sensortag' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
