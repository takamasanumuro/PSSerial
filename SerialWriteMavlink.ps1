#Mavlink checksum calculator
Function CalculateCRC {
    Param (
        [Parameter(Mandatory = $true)]
        [byte]
        $targetByte,
        [Parameter(Mandatory = $true)]
        [ushort]
        $inputChecksum
    )
 
    [int]$checksum = [byte]($targetByte -bxor [byte]($inputChecksum -band 0x00FF))
    $checksum = [byte](0x00FF -band ($checksum -bxor ($checksum -shl 4)))
    [ushort]$calculatedChecksum = [ushort](($inputChecksum -shr 8) -bxor ($checksum -shl 8) -bxor ($checksum -shl 3) -bxor ($checksum -shr 4))
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
Function PrintMavlinkHeader {
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


$startMarker = [byte]0xFE
$length = [byte]0x09
$sequence = [byte]0x00
$systemID = [byte]0xFF
$componentID = [byte]0xBE
$msgID = [byte]0x00
$message = [byte[]]($startMarker, $length, $sequence, $systemID, $componentID, $msgID)
$payload = [byte[]](0x40, 0x00, 0x00, 0x00, 0x06, 0x08, 0x80, 0x03, 0x01)
$payload | ForEach-Object { $message += $_}

$checksum = AccumulateCRC $message $message.Length
$checksumExtra = [byte]0x32
$checksum = CalculateCRC $checksumExtra $checksum
$checksumLow = [byte]($checksum -band 0x00FF)
$checksumHigh = [byte]($checksum -shr 8)
#Append checksum to message
$message += $checksumLow
$message += $checksumHigh
PrintMavlinkHeader $message $message.Length


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
#$inputChecksum = 0xFFFF
#$checksum = 0x96
#$exp1 = ($inputChecksum -shr 8)
#$exp2 = ($checksum -shl 8)
#$exp3 = ($checksum -shl 3)
#$exp4 = ($checksum -shr 4)
#$var = ($exp1 -bxor $exp2 -bxor $exp3 -bxor $exp4)
#$var
#
#$checksum = [byte]0x96
#$exp1 = ($inputChecksum -shr 8)
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