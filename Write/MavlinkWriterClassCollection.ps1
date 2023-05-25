
class MeasurementSystem
{
    [float[]] $currents
    [float] $voltage

    MeasurementSystem()
    {
        $this.currents = [float[]]@(0x00, 0x00, 0x00)
        $this.voltage = [float]0x00
    }

    #If initial state is desired, use this constructor
    MeasurementSystem([float[]] $currents, [float] $voltage)
    {
        $this.currents = $currents
        $this.voltage = $voltage
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
}

class ControlSystem
{
    [float] $dacControlVoltage
    [float] $potentiometerVoltage
    [byte[]] $pumpStates
    [byte] $pumpBitMask

    ControlSystem()
    {
        $this.dacControlVoltage = [float]0x00
        $this.potentiometerVoltage = [float]0x00
        $this.pumpStates = [byte[]]@(0x00, 0x00, 0x00, 0x00)
    }

    #If initial state is desired, use this constructor
    ControlSystem([float] $dacControlVoltage, [float] $potentiometerVoltage, [byte[]] $pumpStates)
    {
        $this.dacControlVoltage = $dacControlVoltage
        $this.potentiometerVoltage = $potentiometerVoltage
        $this.pumpStates = $pumpStates
    }

    [byte[]] GetPumpStates()
    {
        return $this.pumpStates
    }

    [byte] GetPumpBitMask()
    {
        $this.pumpBitMask = [byte]0x00
        for ($i = 0; $i -lt $this.pumpStates.Length; $i++)
        {
            if ($this.pumpStates[$i] -ge 0x01)
            {
                $this.pumpBitMask = $this.pumpBitMask -bor ([byte]0x01 -shl $i)
            }
            else
            {
                $this.pumpBitMask = $this.pumpBitMask -band (0xFF -band (-bnot ([byte]0x01 -shl $i)))
            }
        }
        return $this.pumpBitMask
    }

    [float] GetDACControlVoltage()
    {
        return $this.dacControlVoltage
    }

    [float] GetPotentiometerVoltage()
    {
        return $this.potentiometerVoltage
    }

    [void] SetDACControlVoltage([float] $dacControlVoltage)
    {
        #Limit to 0-5000mV
        if ($dacControlVoltage -lt [float]0)
        {
            $this.$dacControlVoltage = 0.0
        }
        elseif ($dacControlVoltage -gt [float]5000)
        {
            $this.dacControlVoltage = [float]5000
        }
        else
        {
            $this.dacControlVoltage = $dacControlVoltage
        }
        
    }

    [void] SetPotentiometerVoltage([float] $potentiometerVoltage)
    {
        $this.potentiometerVoltage = $potentiometerVoltage
    }

    [void] SetPumpStates([byte[]] $pumpStates)
    {
        if ($pumpStates.Length -ne 4)
        {
            throw "Invalid array length"
        }
        $this.pumpStates = $pumpStates
    }

    [void] SetPumpStates([byte] $state, [int] $index)
    {
        if ($index -lt 0 -or $index -gt 3)
        {
            throw "Index out of range"
        }
        $this.pumpStates[$index] = $state
    }

    [byte[]] ToByteArray()
    {       
        $outBuffer = [byte[]]@()
        $outBuffer += [BitConverter]::GetBytes($this.dacControlVoltage)
        $outBuffer += [BitConverter]::GetBytes($this.potentiometerVoltage)
        $outBuffer += $this.pumpStates
        return $outBuffer        
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

#Class that is the output of MavlinkParser
class MavlinkMessage
{

    [byte] $startMarker
    [byte] $payloadLength
    [byte] $sequence
    [byte] $systemID
    [byte] $componentID
    [byte] $messageID
    [byte[]] $payload
    [short] $checksum

    MavlinkMessage([byte[]] $message)
    {
        $this.startMarker = $message[0]
        $this.payloadLength = $message[1]
        $this.sequence = $message[2]
        $this.systemID = $message[3]
        $this.componentID = $message[4]
        $this.messageID = $message[5]
        $this.payload = $message[6..($message.Length -3)]
        $this.checksum = [BitConverter]::ToInt16($message[($message.Length -2)..($message.Length -1)], 0)
    }

    [byte[]] ToByteArray()
    {
        $outBuffer = [byte[]]@()
        $outBuffer += $this.startMarker
        $outBuffer += $this.payloadLength
        $outBuffer += $this.sequence
        $outBuffer += $this.systemID
        $outBuffer += $this.componentID
        $outBuffer += $this.messageID
        $outBuffer += $this.payload
        $outBuffer += [BitConverter]::GetBytes($this.checksum)
        return $outBuffer
    }
}

#Class that accepts payload byte arrays and parses them into the appropriate mavlink message byte array
class MavlinkParser
{
    [byte] $startMarker
    [byte] $sequence
    [byte] $localSystemID
    [byte] $localComponentID

    $mavlinkMessageInfos = @(
    [MavlinkMessageInfo]::new(0, "HEARTBEAT", 50, 9),
    [MavlinkMessageInfo]::new(170, "PUMP_STATE", 176, 1),
    [MavlinkMessageInfo]::new(171, "PUMP_STATE_INDIVIDUAL", 248, 4),
    [MavlinkMessageInfo]::new(172, "INSTRUMENTATION", 71, 16),
    [MavlinkMessageInfo]::new(173, "MOTOR_CONTROL_SIGNALS", 23, 8),
    [MavlinkMessageInfo]::new(174, "GPS_GPRMC_SENTENCE", 30, 80),
    [MavlinkMessageInfo]::new(175, "GPS_LAT_LNG", 248, 8)
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

class Boat
{
    [MeasurementSystem] $MeasurementSystem
    [ControlSystem] $ControlSystem
    [NavigationSystem] $NavigationSystem
    [MavlinkParser] $MavlinkParser

}

Function PrintMavlinkMessage {
    Param (
        [Parameter(Mandatory = $true)]
        [byte[]]
        $message,
        [Parameter(Mandatory = $true)]
        [ushort]
        $length
    )

    enum MavlinkHeader {
        STX = 0
        LENGTH = 1
        SEQUENCE = 2
        SYSTEM_ID = 3
        COMPONENT_ID = 4
        MESSAGE_ID = 5
        PAYLOAD = 6       
    }

    enum MavlinkChecksum {
        CRC_LOW = 0
        CRC_HIGH = 1
    }

    for ($i = 0; $i -lt [int][MavlinkHeader]::PAYLOAD; $i++)
    {
        Write-Host ("{0, 12} : 0x{1}" -f [MavlinkHeader].GetEnumName($i), $message[$i].ToString(("X2")))
    }

    $checksumLength = 2
    $payloadLength = $length - $checksumLength - [int][MavlinkHeader]::PAYLOAD

    for ($i = 0; $i -lt $payloadLength; $i++)
    {
        Write-Host ("{0, 12} : 0x{1}" -f "Payload[$i]", $message[[int][MavlinkHeader]::PAYLOAD + $i].ToString(("X2")))
    }

    #CRC
    Write-Host ("{0, 12} : 0x{1}" -f "CRC_LOW", $message[$length - 2].ToString(("X2")))
    Write-Host ("{0, 12} : 0x{1}" -f "CRC_HIGH", $message[$length - 1].ToString(("X2")))
}


Function Invoke-Mavlink {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory=$true)]
      [string]$PortName
  )
  $port = [System.IO.Ports.SerialPort]::new($PortName, 9600)
  $port.Open()
  $port.ReadTimeout = 5000
  $port.WriteTimeout = 5000
  $port.DiscardInBuffer()
  $port.DiscardOutBuffer()
  $mavlinkParser = [MavlinkParser]::new()
  $measurer = [MeasurementSystem]::new(@(0x10, 0x08, 0x40), 0x30) #ERRORHERE CHECK CONSTRUCTOR TOMORROW!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  $message = [byte[]]$mavlinkParser.EncodeMessage(172, $measurer.ToByteArray())
  while ($true)
  {
    $port.Write([byte[]]$message, 0, $message.Length)
    PrintMavlinkMessage $message $message.Length
    try
    {
      $inputCommand = Read-Host "Press any key to continue or CTRL+C to exit"
      if ($inputCommand -eq 'q')
      {
        break
      }
    }
    catch
    {
      #Control c exception
      if ($_exception -is [Management.Automation.PipelineStoppedException])
      {
        Write-Host "Exiting gracefully"
        break
      }
    }
  }
  $port.Close()
}

Invoke-Mavlink "COM1"