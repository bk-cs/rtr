## DESCRIPTION
List local firewall rules

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_firewall_rule" -CommandLine=```'{"Log":true}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Log = $true } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_firewall_rule' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
