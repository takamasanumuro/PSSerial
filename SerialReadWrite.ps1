$messageIDTable = @{
  "Voltage" = 0
  "Current" = 1
  "Temperature" = 2
}

$messageValueRangeTable = @{
  "Voltage" = [byte[]]@(48, 52)
  "Current" = [byte[]]@(3, 50)
  "Temperature" = [byte[]]@(20, 70)
}


Function SendPacket {
    Param (
      [Parameter(Mandatory = $true)]
      [System.IO.Ports.SerialPort]
      $serialPort,
      [Parameter(Mandatory = $true)]
      [byte]
      $key,
      [Parameter(Mandatory = $true)]
      [byte]
      $value
    )
    $startMarker = 0xFE
    $serialPort.Write([byte[]]@($startMarker, $key, $value), 0, 3)
}

Function SendPacketRandom {
    Param (
      [Parameter(Mandatory = $true)]
      [System.IO.Ports.SerialPort]
      $serialPort
    )
    $messageIDHash = $messageIDTable.GetEnumerator() | Get-Random
    $messageValue = Get-Random -Minimum $messageValueRangeTable[$messageIDHash.Key][0] -Maximum $messageValueRangeTable[$messageIDHash.Key][1]
    SendPacket $serialPort $messageIDHash.Value $messageValue    
}

$sequence = [int]0
$serialPort = New-Object System.IO.Ports.SerialPort COM1, 9600
$serialPort.Open()

while ($true)
{
    SendPacketRandom $serialPort
    Start-Sleep -Milliseconds 2000
    Write-Host $sequence
    $sequence++
}





