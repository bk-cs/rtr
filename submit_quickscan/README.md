## DESCRIPTION
Submit a file to Falcon X QuickScan. Requires an API Client with 'samples:write', 'quick-scan:read' and
'quick-scan:write'. The script waits 30 seconds for a result, and outputs 'in_progress' if the result has not
been produced by the end of the wait period.

## PARAMETER File
Path to the file (Required)

## PARAMETER Hostname
CrowdStrike Falcon API hostname (Required)

## PARAMETER ClientId
CrowdStrike Falcon OAuth2 API ClientId (Required)

## PARAMETER ClientSecret
CrowdStrike Falcon OAuth2 API ClientSecret (Required)

## PARAMETER MemberCid
CrowdStrike Falcon Member CID

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="submit_quickscan" -CommandLine=```'{"File":"C:\\sample\\example.exe","Hostname":"https://api.crowdstrike.com","ClientId":"my_client_id","ClientSecret":"my_client_secret"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ File = 'C:\sample\example.exe'; Hostname = 'https://api.crowdstrike.com'; ClientId = 'my_client_id'; ClientSecret = 'my_client_secret'} | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='submit_quickscan' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
