# bk-cs/rtr
Scripts and schema for use with CrowdStrike Falcon Real-time Response and Falcon Fusion Workflows.

\[ [US-1](https://falcon.crowdstrike.com/documentation/196/workflows) | [US-2](https://falcon.us-2.crowdstrike.com/documentation/196/workflows) | [US-GOV-1](https://falcon.laggar.gcw.crowdstrike.com/documentation/196/workflows) | [EU-1](https://falcon.eu-1.crowdstrike.com/documentation/196/workflows) \]

**NOTE:** If you enter your Humio `Cloud` and `Token` values inside of the `$Humio` value at the beginning of each
script, the results from the script will be output to Real-time Response and also sent to your Humio repository.

```powershell
$Humio = @{ Cloud = 'https://cloud.community.humio.com'; Token = '<my_ingest_token_guid>' }
```