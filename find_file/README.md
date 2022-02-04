## DESCRIPTION
Perform a recursive search for a file and save results within a Json file in the Rtr directory

## PARAMETER Path
Base directory to begin search

## PARAMETER Filter
Restrict search results using a pattern (Required)

## PARAMETER Include
An array of one or more string patterns to include

## PARAMETER Exclude
An array of one or more string patterns to exclude

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="find_file" -CommandLine=```'{"Path":"C:\\Windows","Filter":"*.exe"}'```
```
### PSFALCON

### FALCONPY
