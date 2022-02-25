## DESCRIPTION
Change the password for a local user

## PLATFORMS
Windows

## PARAMETER Username
Local username (Required)

## PARAMETER Password
Password (Required)

## PARAMETER ForceLogoff
Force logoff if the user has an active session

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="set_local_password" -CommandLine=```'{"Username":"IEUser","Password":"hunter2","ForceLogOff":true,"Cloud":"https://cloud.community.humio.com","Token":"my_token"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Username = 'IEUser'; Password = 'hunter2'; ForceLogoff = $true; Cloud = "https://cloud.community.humio.com"; Token = "my_token" } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='set_local_password' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
