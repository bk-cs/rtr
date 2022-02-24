## DESCRIPTION
Perform a recursive search for a file. Because of the potential for the script to time out when run using
Real-time Response, results will be sent to your Humio instance (if 'Cloud' and 'Token' are provided) or
written to a Json file in the temporary Rtr directory.

## PARAMETER Path
Base directory to begin search (Required)

## PARAMETER Filter
Restrict search results using a pattern (Required)

## PARAMETER Include
An array of one or more string patterns to include

## PARAMETER Exclude
An array of one or more string patterns to exclude

## PARAMETER Cloud
Humio cloud base URL

## PARAMETER Token
Humio ingest token

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="find_file" -CommandLine=```'{"Path":"C:\\Windows","Filter":"notepad*","Include":"*.exe"}'```
```
### PSFALCON
```
PS>$CommandLine = '```' + "'$(@{ Path = 'C:\Windows'; Filter = 'notepad*'; Include = '*.exe' } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='find_file' -CommandLine=$CommandLine" -HostIds <id>, <id>
```
### FALCONPY
