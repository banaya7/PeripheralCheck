#This get copied onto the machine and is locally run. It checks peripherals

function Get-PeripheralStatus {
#These ae the devices checked, can add or subtract devices check "Get-CimInstance Win32_PnPEntity" for more options
    $requiredDevices = @("Monitor", "Keyboard", "Mouse")
    $devices = Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.PNPClass -in $requiredDevices -and $_.Status -eq "OK"
    }

    $report = @()

    foreach ($deviceType in $requiredDevices) {
        $matches = $devices | Where-Object { $_.PNPClass -eq $deviceType }

        if ($deviceType -eq "Keyboard") {
            # Keep kbdhid devices unless obviously virtual
            $matches = $matches | Where-Object {
                $_.Name -notmatch "Remote|RDP|Terminal|Virtual|Hyper-V|ConvertedDevice" -and
                $_.PNPDeviceID -notmatch "CONVERTEDDEVICE"
            }
        }

        if ($matches.Count -eq 0) {
            $report += "{0}:  Not detected" -f $deviceType
        } else {
            $report += "{0}:  OK" -f $deviceType
        }
    }

    return $report
}

#Run function
Get-PeripheralStatus
