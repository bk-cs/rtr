# bk-cs/rtr
Scripts and schema for use with CrowdStrike Falcon Real-time Response and Falcon Fusion.

## Frequently Asked Questions

### Uh, what's wrong with your code?
These scripts are not regular PowerShell/bash/zsh scripts. They've been designed to work with
Falcon Workflows \[ [US-1](https://falcon.crowdstrike.com/documentation/196/workflows) | [US-2](https://falcon.us-2.crowdstrike.com/documentation/196/workflows) | [US-GOV-1](https://falcon.laggar.gcw.crowdstrike.com/documentation/196/workflows) | [EU-1](https://falcon.eu-1.crowdstrike.com/documentation/196/workflows) \].

The included Json input and output schema define what parameters can be automatically populated during a workflow,
and what sort of output is going to be produced by the script.

### How can I avoid entering my Humio credentials every time?
There is a variable named `$Default` at the beginning of each script. You can enter your Humio `Cloud` and `Token`
values here, and they will be used unless you provide new values when you run the script.

## Known issues
### Array output
As of March 2022, the Json schema used in workflows doesn't handle arrays. Most of these scripts output an array of results, which leads to an `The script output does not validate against the output JSON schema` error during a workflow execution. This doesn't matter if the results are being sent to Humio, because the results will still be viewable there.

To fix this, one of these things needs to happen:
* Workflows need to be updated to handle arrays in the way that they're being output by these scripts
* The scripts need to be updated to return a single object with the array inside it

I'm evaluating both options and will update the scripts accordingly to fix it when I can.
