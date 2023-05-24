#Mavlink checksum calculator
Function CalculateCRC {
    Param (
        [Parameter(Mandatory = $true)]
        [byte]
        $targetByte,
        [Parameter(Mandatory = $true)]
        [ushort]
        $inputCommandChecksum
    )
 
    [int]$checksum = [byte]($targetByte -bxor [byte]($inputCommandChecksum -band 0x00FF))
    $checksum = [byte](0x00FF -band ($checksum -bxor ($checksum -shl 4)))
    [ushort]$calculatedChecksum = [ushort](($inputCommandChecksum -shr 8) -bxor ($checksum -shl 8) -bxor ($checksum -shl 3) -bxor ($checksum -shr 4))
    return $calculatedChecksum
}

#Iteration wrapper for CalculateCRC over a target buffer
function AccumulateCRC {
    Param (
        [Parameter(Mandatory = $true)]
        [byte[]]
        $targetBuffer,
        [Parameter(Mandatory = $true)]
        [ushort]
        $length,
        [Parameter(Mandatory = $false)]
        [bool]
        $debugCRC = $false
    )
    $x25InitCRC = [ushort]0xFFFF
    $checksum = [ushort]$x25InitCRC
    #skip STX byte
    for ($i = 1; $i -lt $length; $i++)
    {
        $checksum = CalculateCRC $targetBuffer[$i] $checksum
        if ($debugCRC -eq $true) 
        { 
            Write-Host ("AccChecksum[$i]: 0x{0}" -f $checksum.ToString("X4"))
        }
    }
    return $checksum
}

#Print Mavlink message with hex format, identifying each byte
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


#public static message_info[] MAVLINK_MESSAGE_INFOS = new message_info[] {
#    new message_info(0, "HEARTBEAT", 50, 9, 9, typeof( mavlink_heartbeat_t )), // none 24 bit
#    new message_info(170, "PUMP_STATE", 176, 1, 1, typeof( mavlink_pump_state_t )), // none 24 bit
#    new message_info(171, "PUMP_STATE_INDIVIDUAL", 248, 4, 4, typeof( mavlink_pump_state_individual_t )), // none 24 bit
#    new message_info(172, "INSTRUMENTATION", 71, 16, 16, typeof( mavlink_instrumentation_t )), // none 24 bit
#    new message_info(173, "MOTOR_CONTROL_SIGNALS", 23, 8, 8, typeof( mavlink_motor_control_signals_t )), // none 24 bit
#    new message_info(174, "GPS_GPRMC_SENTENCE", 30, 80, 80, typeof( mavlink_gps_gprmc_sentence_t )), // none 24 bit
#    new message_info(175, "GPS_LAT_LNG", 248, 8, 8, typeof( mavlink_gps_lat_lng_t )), // none 24 bit
#
#};



enum MAVLINK_MSG_LENGTHS {
    HEARTBEAT = 9
    PUMP_STATE = 1
    PUMP_STATE_INDIVIDUAL = 4
    INSTRUMENTATION = 16
    MOTOR_CONTROL_SIGNALS = 8
    GPS_GPRMC_SENTENCE = 80
    GPS_LAT_LNG = 8
}

enum MAVLINK_MSG_ID {
    HEARTBEAT = 0
    PUMP_STATE = 170
    PUMP_STATE_INDIVIDUAL = 171
    INSTRUMENTATION = 172
    MOTOR_CONTROL_SIGNALS = 173
    GPS_GPRMC_SENTENCE = 174
    GPS_LAT_LNG = 175
}

enum MAVLINK_MSG_CRCS {
    HEARTBEAT = 50
    PUMP_STATE = 176
    PUMP_STATE_INDIVIDUAL = 248
    INSTRUMENTATION = 71
    MOTOR_CONTROL_SIGNALS = 23
    GPS_GPRMC_SENTENCE = 30
    GPS_LAT_LNG = 248
}




#[StructLayout(LayoutKind.Sequential,Pack=1,Size=1)]
#///<summary>  Bitfield that encodes whether the pumps are active or not. </summary>
#public struct mavlink_pump_state_t
#{
#    public mavlink_pump_state_t(byte pump_mask) 
#    {
#          this.pump_mask = pump_mask;
#        
#    }
#    /// <summary>Bitfield that encodes whether the pumps are active or not.   </summary>
#    [Units("")]
#    [Description("Bitfield that encodes whether the pumps are active or not.")]
#    public  byte pump_mask;
#
#};
#
#
#/// extensions_start 0
#[StructLayout(LayoutKind.Sequential,Pack=1,Size=4)]
#///<summary>  Send each pump state on a separate variable. </summary>
#public struct mavlink_pump_state_individual_t
#{
#    public mavlink_pump_state_individual_t(byte pump_zero,byte pump_one,byte pump_two,byte pump_three) 
#    {
#          this.pump_zero = pump_zero;
#          this.pump_one = pump_one;
#          this.pump_two = pump_two;
#          this.pump_three = pump_three;
#        
#    }
#    /// <summary>Pump 0 state.   </summary>
#    [Units("")]
#    [Description("Pump 0 state.")]
#    public  byte pump_zero;
#        /// <summary>Pump 1 state.   </summary>
#    [Units("")]
#    [Description("Pump 1 state.")]
#    public  byte pump_one;
#        /// <summary>Pump 2 state.   </summary>
#    [Units("")]
#    [Description("Pump 2 state.")]
#    public  byte pump_two;
#        /// <summary>Pump 3 state.   </summary>
#    [Units("")]
#    [Description("Pump 3 state.")]
#    public  byte pump_three;
#
#};
#
#
#/// extensions_start 0
#[StructLayout(LayoutKind.Sequential,Pack=1,Size=16)]
#///<summary>  Instrumentation data for 3 current sensors and 1 voltage sensor. </summary>
#public struct mavlink_instrumentation_t
#{
#    public mavlink_instrumentation_t(uint current_zero,uint current_one,uint current_two,uint voltage) 
#    {
#          this.current_zero = current_zero;
#          this.current_one = current_one;
#          this.current_two = current_two;
#          this.voltage = voltage;
#        
#    }
#    /// <summary>Current Sensor 0  [mA] </summary>
#    [Units("[mA]")]
#    [Description("Current Sensor 0")]
#    public  uint current_zero;
#        /// <summary>Current sensor 1.  [mA] </summary>
#    [Units("[mA]")]
#    [Description("Current sensor 1.")]
#    public  uint current_one;
#        /// <summary>Current sensor 2.  [mA] </summary>
#    [Units("[mA]")]
#    [Description("Current sensor 2.")]
#    public  uint current_two;
#        /// <summary>Voltage sensor.  [mA] </summary>
#    [Units("[mA]")]
#    [Description("Voltage sensor.")]
#    public  uint voltage;
#
#};
#
#
#/// extensions_start 0
#[StructLayout(LayoutKind.Sequential,Pack=1,Size=8)]
#///<summary>  Output voltage from DAC and potentiometer going to motor. </summary>
#public struct mavlink_motor_control_signals_t
#{
#    public mavlink_motor_control_signals_t(uint dac_output,uint potentiometer_output) 
#    {
#          this.dac_output = dac_output;
#          this.potentiometer_output = potentiometer_output;
#        
#    }
#    /// <summary>DAC output.  [mV] </summary>
#    [Units("[mV]")]
#    [Description("DAC output.")]
#    public  uint dac_output;
#        /// <summary>Potentiometer output.  [mV] </summary>
#    [Units("[mV]")]
#    [Description("Potentiometer output.")]
#    public  uint potentiometer_output;
#
#};
#
#
#/// extensions_start 0
#[StructLayout(LayoutKind.Sequential,Pack=1,Size=80)]
#///<summary>  Output GPRMC NMEA string from GPS sensor.  </summary>
#public struct mavlink_gps_gprmc_sentence_t
#{
#    public mavlink_gps_gprmc_sentence_t(byte[] gprmc_sentence) 
#    {
#          this.gprmc_sentence = gprmc_sentence;
#        
#    }
#    /// <summary>GPRMC NMEA sentence.   </summary>
#    [Units("")]
#    [Description("GPRMC NMEA sentence.")]
#    [MarshalAs(UnmanagedType.ByValArray,SizeConst=80)]
#    public byte[] gprmc_sentence;
#
#};
#
#
#/// extensions_start 0
#[StructLayout(LayoutKind.Sequential,Pack=1,Size=8)]
#///<summary>  Output latitude and longitude from GPS sensor.  </summary>
#public struct mavlink_gps_lat_lng_t
#{
#    public mavlink_gps_lat_lng_t(int latitude,int longitude) 
#    {
#          this.latitude = latitude;
#          this.longitude = longitude;
#        
#    }
#    /// <summary>Latitude.  [degE7] </summary>
#    [Units("[degE7]")]
#    [Description("Latitude.")]
#    public  int latitude;
#        /// <summary>Longitude.  [degE7] </summary>
#    [Units("[degE7]")]
#    [Description("Longitude.")]
#    public  int longitude;
#
#};



#A powershell boat class, which acts as a system in the mavlink network, composed of a MeasurementSystem, which gets 3 currents and 1 output voltage,
#and a ControlSystem, which gets 4 pump states and outputs 1 control voltage to the motor and read the output of a potentiometer.
#It also has a NavigationSystem, which gets GPS data and outputs a GPRMC sentence.

#The boat class is responsible for generating the mavlink packets and sending them to the other systems.

#class Boat 
#{
#    [MeasurementSystem] $MeasurementSystem
#    [ControlSystem] $ControlSystem
#    [NavigationSystem] $NavigationSystem
#    [byte[]] $currents
#    [byte] $voltage
#    [byte[]] $pumpStates
#    [byte] $controlVoltage
#    [byte[]] $gprmcSentence
#    [int] $latitude
#    [int] $longitude
#    [byte[]] $mavlinkPacket
#
#    Boat([MeasurementSystem] $MeasurementSystem, [ControlSystem] $ControlSystem, [NavigationSystem] $NavigationSystem)
#    {
#        $this.MeasurementSystem = $MeasurementSystem
#        $this.ControlSystem = $ControlSystem
#        $this.NavigationSystem = $NavigationSystem
#    }
#
#    [void] SendMavlinkPacket()
#    {
#        $this.currents = $this.MeasurementSystem.GetCurrents()
#        $this.voltage = $this.MeasurementSystem.GetVoltage()
#        $this.pumpStates = $this.ControlSystem.GetPumpStates()
#        $this.controlVoltage = $this.ControlSystem.GetControlVoltage()
#        $this.gprmcSentence = $this.NavigationSystem.GetGPRMCSentence()
#        $this.latitude = $this.NavigationSystem.GetLatitude()
#        $this.longitude = $this.NavigationSystem.GetLongitude()
#        $this.mavlinkPacket = GenerateMavlinkPacket()
#        SendMavlinkPacket($this.mavlinkPacket)
#    }
#
#    [byte[]] GenerateMavlinkPacket()
#    {
#        $startMarker = [byte]0xFE
#        $length = [byte]0x12
#        $sequence = [byte]0x00
#        $systemID = [byte]0x01
#        $componentID = [byte]0xBF
#        $msgID = [byte]0xFC
#        $message = [byte[]]($startMarker, $length, $sequence, $systemID, $componentID, $msgID)
#        $payload = [byte[]]($this.currents, $this.voltage)
#        $payload += [byte[]]($this.pumpStates, $this.controlVoltage)
#        $payload += [byte[]]($this.gprmcSentence)
#        $payload += [byte[]]($this.latitude, $this.longitude)
#        $message += $payload
#
#        $checksum = AccumulateCRC $message $message.Length
#}

class MeasurementSystem
{
    [byte[]] $currents
    [byte] $voltage

    MeasurementSystem()
    {
        $this.currents = [byte[]]@(0x00, 0x00, 0x00)
        $this.voltage = [byte]0x00
    }

    #If initial state is desired, use this constructor
    MeasurementSystem([byte[]] $currents, [byte] $voltage)
    {
        $this.currents = $currents
        $this.voltage = $voltage
    }

    [byte[]] GetCurrents()
    {
        return $this.currents
    }

    [byte] GetVoltage()
    {
        return $this.voltage
    }

    [void] SetCurrents([byte[]] $currents)
    {
        $this.currents = $currents
    }

    [byte[]] GetMeasurements()
    {
        return [byte[]]@($this.currents, $this.voltage)
    }
}

class ControlSystem
{
    [byte[]] $pumpStates
    [byte] $pumpBitMask
    [int] $controlVoltage
    [int] $potentiometerVoltage

    ControlSystem()
    {
        $this.pumpStates = [byte[]]@(0x00, 0x00, 0x00, 0x00)
        $this.controlVoltage = [byte]0x00
        $this.potentiometerVoltage = [byte]0x00
    }

    #If initial state is desired, use this constructor
    ControlSystem([byte[]] $pumpStates, [byte] $controlVoltage, [byte] $potentiometerVoltage)
    {
        $this.pumpStates = $pumpStates
        $this.controlVoltage = $controlVoltage
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

    [int] GetControlVoltage()
    {
        return $this.controlVoltage
    }

    [int] GetPotentiometerVoltage()
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

    [byte[]] GetControlSystem()
    {
        return [byte[]]@($this.pumpStates, $this.controlVoltage, $this.potentiometerVoltage)
    }

}

class NavigationSystem
{
    [byte[]] $gprmcSentence
    [int] $latitude
    [int] $longitude

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

    [buffer[]] ToByteArray()
    {
        $message = [byte[]]@($this.startMarker, $this.payloadLength, $this.sequence, $this.systemID, $this.componentID, $this.messageID, $this.payload, $this.checksum)
        return $message
    }

    [byte] $startMarker
    [byte] $payloadLength
    [byte] $sequence
    [byte] $systemID
    [byte] $componentID
    [byte] $messageID
    [byte[]] $payload
    [byte] $checksum
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

Function GenerateRandomMavlinkPacket {

}


$startMarker = [byte]0xFE
$length = [byte]0x12
$sequence = [byte]0x00
$systemID = [byte]0x01
$componentID = [byte]0xBF
$msgID = [byte]0xFC
$message = [byte[]]($startMarker, $length, $sequence, $systemID, $componentID, $msgID)
$payload = [byte[]](0x20, 0x4E, 0x00, 0x00, 0x96, 0x00, 0x00, 0x00)
$payload += [byte[]]@(0x41, 0x42, 0x43, 0x44)
$payload += [byte[]]@(0x00)*6
$message += $payload

$checksum = AccumulateCRC $message $message.Length
$checksumExtra = [byte]0x2C
$checksum = CalculateCRC $checksumExtra $checksum
$checksumLow = [byte]($checksum -band 0x00FF)
$checksumHigh = [byte]($checksum -shr 8)
#Append checksum to message
$message += $checksumLow
$message += $checksumHigh
PrintMavlinkMessage $message $message.Length


$serialPort = New-Object System.IO.Ports.SerialPort COM1, 9600
$serialPort.Open()

while ($true)
{
    if ($serialPort.IsOpen -eq $false)
    {
        $serialPort.Open()        
    }

 
    $inputCommand = Read-Host "Press to send message"
    if ($inputCommand -eq 'q')
    {
        $serialPort.Close()
        Write-Host "Closing serial port"
        break
    }
    $serialPort.Write($message, 0, $message.Length)
    PrintMavlinkMessage $message $message.Length
}


#|0xFE
#|0x09
#|0x00
#|0xFF
#|0xBE
#|0x00
###|0x40
###|0x00
###|0x00
###|0x00
###|0x06
###|0x08
###|0x80
###|0x03
###|0x01
#|0xE9
#|0xE2


#Bug found!
#$inputCommandChecksum = 0xFFFF
#$checksum = 0x96
#$exp1 = ($inputCommandChecksum -shr 8)
#$exp2 = ($checksum -shl 8)
#$exp3 = ($checksum -shl 3)
#$exp4 = ($checksum -shr 4)
#$var = ($exp1 -bxor $exp2 -bxor $exp3 -bxor $exp4)
#$var
#
#$checksum = [byte]0x96
#$exp1 = ($inputCommandChecksum -shr 8)
#$exp2 = ($checksum -shl 8)
#$exp3 = ($checksum -shl 3)
#$exp4 = ($checksum -shr 4)
#$var = ($exp1 -bxor $exp2 -bxor $exp3 -bxor $exp4)
#$var


#$PS C:\Users\Adriano\Documents\AutoHotkey> $checksum = 0x96
#PS C:\Users\Adriano\Documents\AutoHotkey> ($checksum -shl 8)
#38400
#PS C:\Users\Adriano\Documents\AutoHotkey> $checksum
#150
#PS C:\Users\Adriano\Documents\AutoHotkey> $checksum = [byte]0x96
#PS C:\Users\Adriano\Documents\AutoHotkey> ($checksum -shl 8)
#0
#PS C:\Users\Adriano\Documents\AutoHotkey> $checksum
#150
#PS C:\Users\Adriano\Documents\AutoHotkey>


#Why it works in C# but not here?

#C# TYPE PROMOTION RULES
#In an expression, you can freely mix two or more different types of data as long as they are compatible with each other. For example, you can mix short and long within an expression because they are both numeric types. When different types of data are mixed in an expression, they are converted to the same type using C#’s type promotion rules. The following algorithm is used for binary operations.
#
#IF one operand is a decimal, THEN the other operand is promoted to decimal
#(unless it is of type fl oat or double, in which case an error results).
#
#ELSE IF one operand is a double, the second is promoted to double.
#
#ELSE IF one operand is a fl oat, the second is promoted to float.
#
#ELSE IF one operand is a ulong, the second is promoted to ulong (unless it is of type sbyte, short, int, or long, in which case an error results).
#
#ELSE IF one operand is a long, the second is promoted to long.
#
#ELSE IF one operand is a uint and the second is of type sbyte, short, or int, both are promoted to long.
#
#ELSE IF one operand is a uint, the second is promoted to uint.
#
#ELSE both operands are promoted to int.



#$startMarker = [byte]0xFE
#$length = [byte]0x09
#$sequence = [byte]0x00
#$systemID = [byte]0xFF
#$componentID = [byte]0xBE
#$msgID = [byte]0x00
#$message = [byte[]]($startMarker, $length, $sequence, $systemID, $componentID, $msgID)
#$payload = [byte[]](0x40, 0x00, 0x00, 0x00, 0x06, 0x08, 0x80, 0x03, 0x01)
#$payload | ForEach-Object { $message += $_}