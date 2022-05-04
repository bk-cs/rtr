## DESCRIPTION
Remove 'SensorGroupingTag' values

## PARAMETER SensorTag
One or more SensorTag values (Required)

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="remove_sensortag" -CommandLine=```'{"SensorTag":["my","example","tags"]}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "'$(@{ SensorTag = @('my','example','tags') } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='remove_sensortag' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY