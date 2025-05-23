# PeripheralCheck
A powershell script to be able to scan a network, and determine that all computers are connected to the network, and have their peripheral hardware connected. 
# Peripheral Scan Utility

## Overview

This PowerShell script remotely checks whether a list of domain-joined computers are:

- Online and connected to the network
- Equipped with a monitor, keyboard, and mouse
- Logging scan results per machine
- Sending a full scan report via email to a designated address

The script uses PsExec to execute a custom peripheral scan script remotely, collects the results, logs them, and sends an email summary.

## Author

Brandon Anaya  
Initial release: 2025-05-16

## Requirements

- PowerShell 5.1 or newer
- Administrator privileges
- PsExec from the Sysinternals Suite (PsExec.exe)
- Remote machines must allow:
  - SMB access to `\\COMPUTER\C$\Temp`
  - Remote command execution via PsExec
- Temp directory (`C:\Temp`) must exist or be creatable
- Access to an SMTP server for emailing results

## Setup

### 1. Prepare Your Environment

- Place `PsExec.exe` in a known path like `C:\PSTools\PsExec.exe`
- Create a PowerShell script called `Peripheral_Scan.ps1` that checks for monitor, keyboard, and mouse presence and writes the results to `C:\Temp\PeripheralResults.txt` on the target system
- Create a config `.ini` file with a line like:

- - Create a text file that contains one computer name per line (referenced by the `ComputerList` path)

    ComputerList=Path\To\ComputerList.txt

### 2. Configure the Script

Update the following variables in the script to reflect your environment:

 ``` powershell
$iniPath = "PATH TO YOUR INI FILE"
$psExecPath = "C:\PSTools\PsExec.exe"
$peripheralScript = "PATH TO YOUR PERIPHERAL SCAN PS1 SCRIPT"
$logPath = "PATH TO YOUR LOG DIRECTORY"
$smtpServer = "YOUR SMTP SERVER"
$from = "sender@example.com"
$to = "recipient@example.com"
```
Execute
.\Run-Peripheral-Scan.ps1
