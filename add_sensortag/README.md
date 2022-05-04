## DESCRIPTION
Add 'SensorGroupingTag' values

## PARAMETER SensorTag
An array of one or more SensorTag values (Required)

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="add_sensortag" -CommandLine=```'{"SensorTag":["my","example","tags"]}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "'$(@{ SensorTag = @('my','example','tags') } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='add_sensortag' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY