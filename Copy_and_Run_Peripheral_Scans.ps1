<#
Author: Brandon Anaya
Purpose: Schedule a scan that makes sure the computers are:
Connected to the network and turned on, checks to see that
monitors, keyboard, and mice are all connected.
Also logs results, and emails results
Date: 5/16/2025
#>

$iniPath = "PATH TO YOUR INI FILE"
$psExecPath = "C:\PSTools\PsExec.exe"
$peripheralScript = "PATH TO YOUR PERIPHERAL SCAN PS1 SCRIPT\Peripheral_Scan.ps1"
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = "PATH TO YOUR PERIPHERAL SCAN LOGS\Peripheral_Scan_Results_$timestamp.txt"
# Email the results
$smtpServer = "YOUR SMTP SERVER SO YOU CAN EMAIL LOGS"
$from = "FROM EMAIL"
$to = "TO EMAIL/S"
$subject = "Peripheral Scan Results - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"


# Reading the computer list, making it into a powershell object.
Write-Host "Reading from config: $iniPath"
Add-Content $logPath "Peripheral Scan Results - $(Get-Date)"
Add-Content $logPath "==================================================`n"

$iniContent = Get-Content -Path $iniPath
$computerListFilePath = $iniContent | Where-Object { $_ -match "^ComputerList=" } | ForEach-Object { $_.Split('=')[1].Trim() }

if (-not (Test-Path $computerListFilePath)) {
    Write-Host "[ERROR] Computer list file not found: $computerListFilePath"
    exit
}
#list computers in powershell object
$computers = Get-Content -Path $computerListFilePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
Write-Host "Computers to scan: $($computers -join ', ')"

$scriptBlock = {
    param($computer, $psExecPath, $peripheralScript)
# Function to test if the computers are reachable on the network 
    function Test-OnlineLocal {
        param ($computerName)
        if (Test-Connection -ComputerName $computerName -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            return $true
        } else {
            try {
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $asyncResult = $tcpClient.BeginConnect($computerName, 445, $null, $null)
                $waitHandle = $asyncResult.AsyncWaitHandle.WaitOne(2000)
                if ($waitHandle) {
                    $tcpClient.EndConnect($asyncResult)
                    $tcpClient.Close()
                    return $true
                }
                $tcpClient.Close()
                return $false
            } catch {
                return $false
            }
        }
    }

    try {
        $result = [PSCustomObject]@{
            ComputerName = $computer
            Status       = ""
            Output       = @()
        }

        if (-not (Test-OnlineLocal $computer)) {
            $result.Status = "OFFLINE"
            return $result
        }

        # Copy the peripheral script
        Copy-Item -Path $peripheralScript -Destination "\\$computer\C$\Temp\" -Force -ErrorAction Stop

        $remoteScript = "C:\Temp\Peripheral_Scan.ps1"
        $outputFile = "\\$computer\C$\Temp\PeripheralResults.txt"

        # PsExec command with output and error streams redirected to null to suppress console noise
        $command = "powershell -NoProfile -ExecutionPolicy Bypass -File $remoteScript > $outputFile 2>&1"

        try {
            # Run PsExec, redirect all output to null
            & $psExecPath -accepteula \\$computer -h -s cmd /c "$command" *> $null 2>&1
        } catch {
            $result.Status = "ERROR"
            $result.Output = @("PsExec failed: $_")
            return $result
        }

        Start-Sleep -Seconds 5

        if (Test-Path $outputFile) {
            $output = Get-Content $outputFile -ErrorAction SilentlyContinue
            if ($null -eq $output -or $output.Count -eq 0) {
                $result.Status = "NO_OUTPUT"
                $result.Output = @("No output found in result file.")
            } else {
                $result.Status = "OK"
                $result.Output = $output
            }
        } else {
            $result.Status = "NO_OUTPUT_FILE"
            $result.Output = @("Output file missing; script may have failed or never ran.")
        }

        Remove-Item "\\$computer\C$\Temp\Peripheral_Scan.ps1" -Force -ErrorAction SilentlyContinue
        Remove-Item "\\$computer\C$\Temp\PeripheralResults.txt" -Force -ErrorAction SilentlyContinue

        return $result
    }
    catch {
        return [PSCustomObject]@{
            ComputerName = $computer
            Status       = "ERROR"
            Output       = @("Error during execution: $_")
        }
    }
}

# ----- BEGIN THROTTLED JOB START -----

$maxConcurrentJobs = 30
$jobs = @()
$allJobs = @()

foreach ($computer in $computers) {
    while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $maxConcurrentJobs) {
        Start-Sleep -Seconds 5
    }

    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $computer, $psExecPath, $peripheralScript
    $jobs += $job
    $allJobs += $job
}


# Wait for all jobs to finish and get results
$allJobs | Wait-Job
$results = $allJobs | Receive-Job
$allJobs | Remove-Job


$validResults = $results | Where-Object {
    $_ -ne $null -and
    $_.PSObject.Properties.Name.Contains('ComputerName') -and
    -not [string]::IsNullOrWhiteSpace($_.ComputerName)
}

$offlineComputers = $validResults | Where-Object { $_.Status -eq "OFFLINE" }
$otherResults = $validResults | Where-Object { $_.Status -ne "OFFLINE" }

Set-Content $logPath "Peripheral Scan Results - $(Get-Date)"
Add-Content $logPath "==================================================`n"

if ($offlineComputers.Count -gt 0) {
    Add-Content $logPath "=== OFFLINE COMPUTERS (Not reachable) ==="
    foreach ($offComp in $offlineComputers) {
        Add-Content $logPath $offComp.ComputerName
    }
    Add-Content $logPath "`n"
} else {
    Add-Content $logPath "All computers are reachable on the network.`n"
}

foreach ($res in $otherResults) {
    Add-Content $logPath "=== $($res.ComputerName) ==="
    switch ($res.Status) {
        "NO_OUTPUT_FILE" {
            Add-Content $logPath "Issue detected: No output file found; script may have failed or never ran."
        }
        "NO_OUTPUT" {
            Add-Content $logPath "Issue detected: No output found in peripheral scan results."
        }
        "ERROR" {
            Add-Content $logPath "Issue detected: $($res.Output -join "`n")"
        }
        "OK" {
            $missingDevices = @()
            foreach ($line in $res.Output) {
                if ($line -match "Not detected") {
                    if ($line -match "Monitor") { $missingDevices += "Monitor" }
                    if ($line -match "Keyboard") { $missingDevices += "Keyboard" }
                    if ($line -match "Mouse") { $missingDevices += "Mouse" }
                }
            }
            if ($missingDevices.Count -eq 0) {
                Add-Content $logPath "Peripherals : OK"
            } else {
                Add-Content $logPath "Issue detected: $($missingDevices -join ', ') not connected"
            }
        }
        Default {
            Add-Content $logPath "Unknown status: $($res.Status)"
            Add-Content $logPath ($res.Output -join "`n")
        }
    }
    Add-Content $logPath "`n"
}

$body = Get-Content $logPath | Out-String

Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtpServer

Write-Host "`nScan complete. Results logged to: $logPath"
