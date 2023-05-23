
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

Function ProcessData {
    Param (
      [Parameter(Mandatory = $true)]
      [System.IO.Ports.SerialPort]
      $serialPort,
      [Parameter(Mandatory = $true)]
      [byte]
      $messageIDNumber,
      [Parameter(Mandatory = $true)]
      [int]
      $messageValue
    )

    $messageIDTable | ForEach-Object {
      if ($_.Value -eq $messageIDNumber) 
      {
          $messageIDName = $_.Key
      }    
    }

    Write-Host "[$messageIDName]: $messageValue"
}


# Function to parse the received data non blocking
Function ParseData {

    Param (
        [Parameter(Mandatory=$true)]
        [System.IO.Ports.SerialPort]
        $serialPort        
    )
   
    $startMarker = 0xFE
    $key = 0x00
    $value = 0x00
    $state = 0
    $data = ""
    $previousTime = Get-Date
    $sequence = 0

    while ($serialPort.IsOpen -eq $false)
    {
        Write-Host "Opening serial port"
        $serialPort.Open()
        Start-Sleep -Milliseconds 500      
    }

    while($true) 
    {   
        while ($serialPort.BytesToRead)
        {   
            Write-Host "Before read"     
            $byte = $serialPort.ReadByte()
            Write-Host "Received $byte"
    
            if (($byte -eq $startMarker) -and ($state -eq 0))
            {
                $state = 1
                Write-Host "Start marker received"
            }
              
            elseif ($state -eq 1)
            {
                $key = $byte
                $state = 2
                Write-Host "Key received"
            }
    
            elseif ($state -eq 2)
            {
                Write-Host "Value received"
                $value = $byte
                $state = 0
                $data = "0x{0:X2} / 0x{1:X2} / 0x{2:X2}" -f $startMarker, $key, $value
                Write-Host "[Packet]$data`n"              
                $data = ""
            }       
        }

        # Print heartbeat every 1 second
        if ((Get-Date) -gt $previousTime.AddSeconds(1))
        {
          Write-Host "Heartbeat[$sequence]"
          $sequence++
          $previousTime = Get-Date
        }
    }  
}

$serialPort = New-Object System.IO.Ports.SerialPort COM2, 9600
if ($serialPort.IsOpen -eq $false)
{
    $serialPort.Open()
}
ParseData $serialPort
