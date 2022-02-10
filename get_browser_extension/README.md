## DESCRIPTION
List installed extensions for Chromium-based (Chrome, Edge) browsers

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_browser_extension" -CommandLine=```'{"Filter":"CrowdScrape"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Filter = 'CrowdScrape'; Log = $true } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_browser_extension' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY

