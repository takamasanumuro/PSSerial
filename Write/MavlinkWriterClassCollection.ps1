
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

  [void] SetCurrents([byte[]] $currents)
  {
      $this.currents = $currents
  }

  [void] SetVoltage([byte] $voltage)
  {
      $this.voltage = $voltage
  }

  [byte[]] ToByteArray()
  {
      return [byte[]]@($this.currents + $this.voltage)
  }
}

class ControlSystem
{
  [float] $controlVoltage
  [float] $potentiometerVoltage
  [byte[]] $pumpStates
  [byte] $pumpBitMask

  ControlSystem()
  {
    $this.controlVoltage = [float]0x00
    $this.potentiometerVoltage = [float]0x00
    $this.pumpStates = [byte[]]@(0x00, 0x00, 0x00, 0x00)
  }

  #If initial state is desired, use this constructor
  ControlSystem([float] $controlVoltage, [float] $potentiometerVoltage, [byte[]] $pumpStates)
  {
    $this.controlVoltage = $controlVoltage
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

  [float] GetControlVoltage()
  {
      return $this.controlVoltage
  }

  [float] GetPotentiometerVoltage()
  {
      return $this.potentiometerVoltage
  }

  [void] SetControlVoltage([int] $controlVoltage)
  {
      #Limit to 0-5000mV
      if ($controlVoltage -lt 0)
      {
          $this.$controlVoltage = 0
      }
      elseif ($controlVoltage -gt 5000)
      {
          $this.controlVoltage = 5000
      }
      else
      {
          $this.controlVoltage = $controlVoltage
      }
    
  }

  [void] SetPotentiometerVoltage([int] $potentiometerVoltage)
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
      return [byte[]]@($this.pumpStates, $this.controlVoltage, $this.potentiometerVoltage)
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
      $this.gprmcSentence = [byte[]]@(0x00)*82
      $this.latitude = [int]0x00
      $this.longitude = [int]0x00
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
      return [byte[]]@($this.latitude, $this.longitude)
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

  #Minimum length field is not required for Mavlink1.0
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
  [byte] $checksum

  MavlinkMessage([byte[]] $message)
  {
      $this.startMarker = $message[0]
      $this.payloadLength = $message[1]
      $this.sequence = $message[2]
      $this.systemID = $message[3]
      $this.componentID = $message[4]
      $this.messageID = $message[5]
      $this.payload = $message[6..($message.Length -3)]
      $this.checksum = $message[$message.Length -2]      
  }

  [byte[]] ToByteArray()
  {
      $message = [byte[]]@($this.startMarker, $this.payloadLength, $this.sequence, $this.systemID, $this.componentID, $this.messageID, $this.payload, $this.checksum)
      return $message
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

  
  [int] CalculateChecksum([byte] $targetByte, [int] $inputChecksum)
  {
      #CRC16 Mavlink 
      [int]$checksum = [byte]($targetByte -bxor [byte]($inputChecksum -band 0x00FF))
      $checksum = [byte](0x00FF -band ($checksum -bxor ($checksum -shl 4)))
      [ushort]$calculatedChecksum = [ushort](($inputChecksum -shr 8) -bxor ($checksum -shl 8) -bxor ($checksum -shl 3) -bxor ($checksum -shr 4))
      return $calculatedChecksum

  }

  [int] AccumulateChecksum([byte[]] $targetBuffer, [int] $crcExtra)
  {
      $initialChecksum = 0xFFFF
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
          $messageInfo = $this.mavlinkMessageInfos | Where-Object ($_ -eq $messageID)
          if (($null -eq $messageInfo) -or ($messageInfo.Length -ne $payload.Length))
          {
              throw "Invalid message ID"
          }
          
          $messageBuffer = [byte[]]@($this.startMarker, $messageInfo.length, $this.sequence, $this.localSystemID, $this.localComponentID, $messageID, $payload)
          $checksum = $this.AccumulateChecksum($messageBuffer, $messageInfo.crcExtra)
          $messageBuffer += [byte[]]@(0xFF -band ($checksum), 0xFF -band ($checksum -shr 8))
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

Function Invoke-Mavlink {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory=$true)]
      [string]$PortName = "COM1"
  )
  $port = [System.IO.Ports.SerialPort]::new($PortName, 9600)
  $port.Open()
  $port.ReadTimeout = 5000
  $port.WriteTimeout = 5000
  $port.DiscardInBuffer()
  $port.DiscardOutBuffer()
  $mavlinkParser = [MavlinkParser]::new()
  $measurer = [MeasurementSystem]::new(@(0x10, 0x08, 0x40), 0x30)
  $message = [byte[]]$mavlinkParser.EncodeMessage(172, $measurer.ToByteArray())
  while ($true)
  {
    $port.Write($message, 0, $message.Length)
    Write-Host $message
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