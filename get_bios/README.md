## DESCRIPTION
List BIOS information

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="get_bios"
```
### PSFALCON
```powershell
PS>Invoke-FalconRtr runscript "-CloudFile='get_bios' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY