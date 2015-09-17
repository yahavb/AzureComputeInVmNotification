# This sample uses the native powershell functionality for pulling dynamic metadata from a Windows Azure VM for incoming reboot events caused by planned maintenance. 
# When reboot is pending, it will log an event in the EventLog.
# Before executing it, the event needs to be registered in the EventLogger by executing: New-EventLog –LogName Application –Source “IsVmInMaint”

$result=curl http://169.254.169.254/metadata/v1/InstanceInfo | findstr "^Content" | findstr -i EventID
if ($result) {Write-EventLog -LogName Application –Source "IsVmInMaint" -EntryType Information –EventID 1 –Message "Incoming VM reboot"}
