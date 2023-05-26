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
    #Check whether to use int or float
    [int] $latitude
    [int] $longitude
    [byte[]] $gprmcSentence

    NavigationSystem()
    {
        $this.latitude = [int]0x00
        $this.longitude = [int]0x00
        $this.gprmcSentence = [byte[]]@(0x00)*82
    }

    #If initial state is desired, use this constructor
    NavigationSystem([byte[]] $gprmcSentence, [int] $latitude, [int] $longitude)
    {
        $this.gprmcSentence = $gprmcSentence
        $this.latitude = $latitude
        $this.longitude = $longitude
    }

    [byte[]] GetGPRMCSentence()
    {
        return $this.gprmcSentence
    }

    [int] GetLatitude()
    {
        return $this.latitude
    }

    [int] GetLongitude()
    {
        return $this.longitude
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

    [byte[]] GetCoordinates()
    {
        $outBuffer = [byte[]]@()
        $outBuffer += [BitConverter]::GetBytes($this.latitude)
        $outBuffer += [BitConverter]::GetBytes($this.longitude)
        return $outBuffer
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
    $queue = [System.Collections.Queue]::new()
    $measurementSystem = [MeasurementSystem]::new()
    $measurementSystem.SetRandom(0.0, 5.0)
    $queue.Enqueue($measurementSystem.ToMavlinkMessage())
    
    $controlSystem = [ControlSystem]::new()
    $controlSystem.SetRandom(0.0, 5.0)
    $queue.Enqueue($controlSystem.ToMavlinkMessage())
    
    $port = [System.IO.Ports.SerialPort]::new("COM3", 9600)
    $port.Open()
    Write-Host "Queue length: $($queue.Count)"
    foreach ($message in $queue)
    {
        $port.Write($message, 0, $message.Length);
        Write-Host "Packet"
        foreach ($byte in $message)
        {
            Write-Host $byte.ToString("X2")
        }
    }
        
}
catch
{
    Write-Host $_.Exception.Message
}
finally
{
    $port.Close()
}

