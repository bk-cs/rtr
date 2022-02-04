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

## PARAMETER Log
Save results within a Json file in the Rtr directory

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="set_local_password" -CommandLine=```'{"Username":"IEUser","Password":"hunter2","ForceLogOff":true,"Log":true}'```
```
### PSFALCON

### FALCONPY
