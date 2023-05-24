$serialPort = New-Object System.IO.Ports.SerialPort COM1, 9600
$serialPort.Open()

$action = {
  while ($Sender.BytesToRead)
  {
    $Sender.ReadByte().ToString("X2") | Out-Host
  }
}

$serialJob = Register-ObjectEvent -InputObject $serialPort -EventName "DataReceived" -Action $action

while ($true) 
{

}

Unregister-Event -SourceIdentifier $serialJob.Name