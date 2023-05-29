class MavlinkMessageInfo
{
    [int] $messageID
    [string] $messageName
    [int] $crcExtra
    [int] $length

    MavlinkMessageInfo([int] $messageID, [string] $messageName, [int] $crcExtra, [int] $length)
    {
        $this.messageID = $messageID
        $this.messageName = $messageName
        $this.crcExtra = $crcExtra
        $this.length = $length
    }

    #Minimum length field is not required for Mavlink 1.0
}

class MavlinkParser
{  
    [byte] $startMarker
    [byte] $sequence
    [byte] $localSystemID
    [byte] $localComponentID

    $mavlinkMessageInfos = @(
        [MavlinkMessageInfo]::new(0, "HEARTBEAT", 50, 9),
        [MavlinkMessageInfo]::new(170, "CONTROL_SYSTEM", 202, 9),
        [MavlinkMessageInfo]::new(171, "INSTRUMENTATION", 179, 16),
        [MavlinkMessageInfo]::new(172, "TEMPERATURES", 60, 8),
        [MavlinkMessageInfo]::new(176, "GPS_GPRMC_SENTENCE", 30, 80),
        [MavlinkMessageInfo]::new(177, "GPS_GPGGA_SENTENCE", 86, 80)
    )

    MavlinkParser()
    {
        $this.startMarker = [byte]0xFE #MavlinkV1.0
        $this.sequence = [byte]0x00
        $this.localSystemID = [byte]0x01
        $this.localComponentID = [byte]0xBF #Onboard computer
    }

  
    [ushort] CalculateChecksum([byte] $targetByte, [ushort] $inputChecksum)
    {
        #CRC16 Mavlink 
        [ushort]$checksum = [byte]($targetByte -bxor [byte]($inputChecksum -band 0x00FF))
        $checksum = [byte](0x00FF -band ($checksum -bxor ($checksum -shl 4)))
        [ushort]$calculatedChecksum = [ushort](($inputChecksum -shr 8) -bxor ($checksum -shl 8) -bxor ($checksum -shl 3) -bxor ($checksum -shr 4))
        return $calculatedChecksum

    }

    [ushort] AccumulateChecksum([byte[]] $targetBuffer, [byte] $crcExtra)
    {
        $initialChecksum = [ushort]0xFFFF
        $checksum = $initialChecksum
        for ($i = 1; $i -lt $targetBuffer.Length; $i++) # Start at 1 to skip start marker
        {
            $checksum = $this.CalculateChecksum($targetBuffer[$i], $checksum)
        }
        $checksum = $this.CalculateChecksum($crcExtra, $checksum)
        return $checksum
    }

    [byte[]] EncodeMessage([byte] $messageID, [byte[]] $payload)
    {
        try {
            $messageInfo = $null
            foreach ($info in $this.mavlinkMessageInfos)
            {
                if ($info.messageID -eq $messageID)
                {
                    $messageInfo = $info
                    break
                }
            }
            if (($null -eq $messageInfo) -or ($messageInfo.Length -ne $payload.Length))
            {
                throw "Invalid message ID"
            }
            
            $messageBuffer = [byte[]]@($this.startMarker, $messageInfo.length, $this.sequence, $this.localSystemID, $this.localComponentID, $messageID)
            $messageBuffer += $payload
            $checksum = $this.AccumulateChecksum($messageBuffer, $messageInfo.crcExtra)
            $messageBuffer += [BitConverter]::GetBytes($checksum)
            $this.sequence++ #Increment sequence number every packet built
            return $messageBuffer
        }
        catch {
            Write-Host "An error occurred"
            return $null
        }            
    }  
}

class ControlSystem
{
    [MavlinkParser] $mavParser
    [float] $dacControlVoltage
    [float] $potentiometerVoltage
    [byte] $pumpBitMask
    [byte] $numberPumps
    [byte] $messageID

    ControlSystem()
    {
        $this.mavParser = [MavlinkParser]::new()
        $this.dacControlVoltage = [float]0x00
        $this.potentiometerVoltage = [float]0x00
        $this.numberPumps = [byte]0x02
        $this.pumpBitMask = [byte]0x00
        
        foreach ($info in $this.mavParser.mavlinkMessageInfos)
        {
            if ($info.messageName -eq "CONTROL_SYSTEM")
            {
                $this.messageID = $info.messageID
                break
            }
        }
    }

    #If initial state is desired, use this constructor
    ControlSystem([float] $dacControlVoltage, [float] $potentiometerVoltage, [byte] $pumpBitMask, [byte] $numberPumps)
    {
        $this.mavParser = [MavlinkParser]::new()
        $this.dacControlVoltage = $dacControlVoltage
        $this.potentiometerVoltage = $potentiometerVoltage
        $this.numberPumps = $numberPumps
        #Check input bitmask according to numberPumps
        if ($pumpBitMask -gt [byte]([Math]::Pow(2, $numberPumps) - 1))
        {
            throw "Invalid pump bitmask"
        }
        $this.pumpBitMask = $pumpBitMask

        foreach ($info in $this.mavParser.mavlinkMessageInfos)
        {
            if ($info.messageName -eq "CONTROL_SYSTEM")
            {
                $this.messageID = $info.messageID
                break
            }
        }

    }

    [float] GetDACControlVoltage()
    {
        return $this.dacControlVoltage
    }

    [float] GetPotentiometerVoltage()
    {
        return $this.potentiometerVoltage
    }

    [byte] GetPumpBitMask()
    {
        return $this.pumpBitMask
    } 

    [byte] GetNumberPumps()
    {
        return $this.numberPumps
    }

    [void] SetDACControlVoltage([float] $dacControlVoltage)
    {
        #Limit to 0-5000mV
        if ($dacControlVoltage -lt [float]0)
        {
            $this.$dacControlVoltage = [float]0
        }
        elseif ($dacControlVoltage -gt [float]3300)
        {
            $this.dacControlVoltage = [float]3300
        }
        else
        {
            $this.dacControlVoltage = $dacControlVoltage
        }
        
    }

    [void] SetPotentiometerVoltage([float] $potentiometerVoltage)
    {
        if ($potentiometerVoltage -lt [float]0)
        {
            $this.potentiometerVoltage = [float]0
        }
        elseif ($potentiometerVoltage -gt [float]5000)
        {
            $this.potentiometerVoltage = [float]5000
        }
        else
        {
            $this.potentiometerVoltage = $potentiometerVoltage
        }  
    }

    [void] SetPumpMask([byte] $mask, [int] $index)
    {

        if (($index -lt 0) -or ($index -ge $this.numberPumps))
        {
            throw "Invalid pump index"
        }

        #Bitwise operations
        if ($mask -gt 0)
        {
            $this.pumpBitMask = $this.pumpBitMask -bor ([byte]1 -shl $index)
        }
        else
        {
            $this.pumpBitMask = $this.pumpBitMask -band (-bnot ([byte]1 -shl $index))
        }
        
    }

    [void] SetRandom($min, $max)
    {
        $random = [System.Random]::new()
        $this.dacControlVoltage = $random.NextDouble() * ($max - $min) + $min
        $this.potentiometerVoltage = $random.NextDouble() * ($max - $min) + $min
        for ($i = 0; $i -lt $this.numberPumps; $i++)
        {
            $this.SetPumpMask($random.Next(0, 2), $i)
        }
        
    }

    [byte[]] ToByteArray()
    {       
        $outBuffer = [byte[]]@()
        $outBuffer += [BitConverter]::GetBytes($this.dacControlVoltage)
        $outBuffer += [BitConverter]::GetBytes($this.potentiometerVoltage)
        $outBuffer += $this.pumpBitMask
        return $outBuffer        
    }

    [byte[]] ToMavlinkMessage()
    {
        $outBuffer = $this.ToByteArray()
        return $this.mavParser.EncodeMessage($this.messageID, $outBuffer)
    }

}

class NavigationSystem
{
    [MavlinkParser] $mavParser
    #Check whether to use int or float
    [int] $latitude
    [int] $longitude
    [byte[]] $gprmcSentence
    [byte] $messageID

    NavigationSystem()
    {
        $this.mavParser = [MavlinkParser]::new()
        $this.latitude = [int]0x00
        $this.longitude = [int]0x00
        $this.gprmcSentence = [System.Text.Encoding]::ASCII.GetBytes('$GPRMC,003448.085,A,2251.408,S,04305.730,W,022.8,033.9,290523,000.0,W*73')

        foreach ($info in $this.mavParser.mavlinkMessageInfos)
        {
            if ($info.messageName -eq "GPS_GPRMC_SENTENCE")
            {
                $this.messageID = $info.messageID
                break
            }
        }
    }

    #If initial state is desired, use this constructor
    NavigationSystem([int] $latitude, [int] $longitude, [byte[]] $gprmcSentence)
    {
        $this.mavParser = [MavlinkParser]::new()
        $this.latitude = $latitude
        $this.longitude = $longitude
        $this.gprmcSentence = $gprmcSentence

        foreach ($info in $this.mavParser.mavlinkMessageInfos)
        {
            if ($info.messageName -eq "GPS_GPRMC_SENTENCE")
            {
                $this.messageID = $info.messageID
                break
            }
        }
    }

    [byte[]] GetGPRMCSentence()
    {
        return $this.gprmcSentence
    }

    [byte[]] GetCoordinates()
    {
        $outBuffer = [byte[]]@()
        $outBuffer += [BitConverter]::GetBytes($this.latitude)
        $outBuffer += [BitConverter]::GetBytes($this.longitude)
        return $outBuffer
    }
   
    [byte[]] GetMessage()
    {
        $outBuffer = $this.GetCoordinates()
        $outBuffer += $this.gprmcSentence
        return $outBuffer
    }

    [void] SetGPRMCSentence([byte[]] $gprmcSentence)
    {
        $this.gprmcSentence = $gprmcSentence
    }

    [void] SetLatitude([int] $latitude)
    {
        $this.latitude = $latitude
    }

    [void] SetLongitude([int] $longitude)
    {
        $this.longitude = $longitude
    }

    [byte[]] ToMavlinkMessage()
    {
        $outBuffer = $this.GetMessage()
        return $this.mavParser.EncodeMessage($this.messageID, $outBuffer)
    }

}

class MeasurementSystem
{
    [MavlinkParser] $mavParser
    [float[]] $currents
    [float] $voltage
    [byte] $messageID

    MeasurementSystem()
    {
        $this.mavParser = [MavlinkParser]::new()
        $this.currents = [float[]]@(0x00, 0x00, 0x00)
        $this.voltage = [float]0x00
        foreach ($info in $this.mavParser.mavlinkMessageInfos)
        {
            if ($info.messageName -eq "INSTRUMENTATION")
            {
                $this.messageID = $info.messageID
                break
            }
        }
    }

    #If initial state is desired, use this constructor
    MeasurementSystem([float[]] $currents, [float] $voltage)
    {
        $this.mavParser = [MavlinkParser]::new()
        if ($currents.Length -ne 3)
        {
            throw "Invalid number of currents"
        }
        $this.currents = $currents
        $this.voltage = $voltage

        foreach ($info in $this.mavParser.mavlinkMessageInfos)
        {
            if ($info.messageName -eq "INSTRUMENTATION")
            {
                $this.messageID = $info.messageID
                break
            }
        }    
    }

    [float[]] GetCurrents()
    {
        return $this.currents
    }

    [float] GetVoltage()
    {
        return $this.voltage
    }

    [void] SetCurrents([float[]] $currents)
    {
        $this.currents = $currents
    }

    [void] SetVoltage([float] $voltage)
    {
        $this.voltage = $voltage
    }

    [void] SetRandom([float] $min, [float] $max)
    {
        $random = [System.Random]::new()
        for ($i = 0; $i -lt $this.currents.Length; $i++)
        {
            $this.currents[$i] = $random.NextDouble() * ($max - $min) + $min
        }
        $this.voltage = $random.NextDouble() * ($max - $min) + $min
    }

    [byte[]] ToByteArray()
    {
        $outBuffer = [byte[]]@()
        foreach ($current in $this.currents)
        {
            $outBuffer += [BitConverter]::GetBytes($current)
        }
        $outBuffer += [BitConverter]::GetBytes($this.voltage)
        return $outBuffer        
    }

    [byte[]] ToMavlinkMessage()
    {
        $outBuffer = $this.ToByteArray()
        return $this.mavParser.EncodeMessage($this.messageID, $outBuffer)
    }
}

try
{
    $queue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())

    $measurementSystem = [MeasurementSystem]::new()
    $timerMeasurement = [System.Timers.Timer]::new()
    $timerMeasurement.Interval = 1000
    Register-ObjectEvent -InputObject $timerMeasurement -EventName Elapsed -SourceIdentifier MavlinkTimerMeasurement -Action{
        $measurementSystem.SetRandom(0.0, 5.0)
        [byte[]] $measurementMessage = $measurementSystem.ToMavlinkMessage()
        if ($null -eq $measurementMessage) 
        {
            "Measurement error $((Get-Date).ToString("HH:mm:ss"))" >> "log.txt"
            return
        }
        $queue.Enqueue($measurementMessage)
    }

    $controlSystem = [ControlSystem]::new()
    $timerControl = [System.Timers.Timer]::new()
    $timerControl.Interval = 2000
    Register-ObjectEvent -InputObject $timerControl -EventName Elapsed -SourceIdentifier MavlinkTimerControl -Action{
        $controlSystem.SetRandom(0.0, 5.0)
        [byte[]] $controlMessage = $controlSystem.ToMavlinkMessage()
        if ($null -eq $controlMessage) 
        {
            "Control error $((Get-Date).ToString("HH:mm:ss"))" >> "log.txt"
            return
        }
        $queue.Enqueue($controlMessage)
    }

    $navSystem = [NavigationSystem]::new()
    $timerNav = [System.Timers.Timer]::new()
    $timerNav.Interval = 3000
    Register-ObjectEvent -InputObject $timerNav -EventName Elapsed -SourceIdentifier MavlinkTimerNav -Action{
        [byte[]] $navMessage = $navSystem.ToMavlinkMessage()
        if ($null -eq $navMessage) 
        {
            "Navigation error $((Get-Date).ToString("HH:mm:ss"))" >> "log.txt"
            return
        }
        $queue.Enqueue($navMessage)
    }

    $timerMeasurement.Start()
    $timerControl.Start()
    $timerNav.Start()

    $port = [System.IO.Ports.SerialPort]::new("COM1", 9600)
    $port.Open()

    while ($true)
    {
        if ($queue.Count -gt 0)
        {
            [byte[]] $message = $queue.Dequeue()
            if ($null -eq $message) { Write-Host "`nNull message from queue" ;continue }     
            $port.Write([byte[]]$message, 0, $message.Length)            
            foreach ($byte in $message)
            {
                Write-Host "$($byte.ToString("X2"))" -NoNewline
            }
            Write-Host "`r" -NoNewline
        }
    }
            
}
catch
{
    #Write-Host $_.Exception.Message
}
finally
{
    $port.Close()
    $timerMeasurement.Stop(); Unregister-Event -SourceIdentifier MavlinkTimerMeasurement
    $timerControl.Stop(); Unregister-Event -SourceIdentifier MavlinkTimerControl
    $timerNav.Stop(); Unregister-Event -SourceIdentifier MavlinkTimerNav

}

