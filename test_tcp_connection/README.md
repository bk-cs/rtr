## DESCRIPTION
Attempt a TCP connection

## PARAMETER Destination
Destination IP address or Hostname

## PARAMETER Port
Destination TCP port

## EXAMPLES

### REAL-TIME RESPONSE
```
runscript -CloudFile="test_tcp_connection" -CommandLine=```'{"Destination":"google.com","Port":80}'```
```
### PSFALCON
```powershell
PS>$CommandLine = '```' + "'$(@{ Destination = 'google.com'; Port = 80 } | ConvertTo-Json -Compress)'" + '```'
PS>Invoke-FalconRtr runscript "-CloudFile='test_tcp_connection' -CommandLine=$CommandLine" -HostId <id>, <id>
```
### FALCONPY