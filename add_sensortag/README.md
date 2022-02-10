## DESCRIPTION
Add 'SensorGroupingTag' values

## PARAMETER SensorTag
One or more SensorTag values (Required)

## PARAMETER Log
Save results within a Json file in the Rtr directory

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
