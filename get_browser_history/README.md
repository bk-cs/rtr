## DESCRIPTION
List history of visited domains for Chromium-based (Chrome, Edge) browsers

## PARAMETER Filter
Restrict list using a RegEx pattern

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_browser_history" -CommandLine=```'{"Filter":"crowdstrike\\.com"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Filter = 'crowdstrike\.com' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='get_browser_history' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY

