# This sample uses the native bash functionality for pulling dynamic metadata from a Windows Azure VM for incoming reboot events caused by planned maintenance. 
# When reboot is pending, it will log an event in the Linux system log using the syslog protocol.
# Add the following line to your local crontab. It will execute the script every 5 minutes 
# */5 * * * * /home/user/IsVmInMaint.sh
#!/bin/bash
result=`curl http://169.254.169.254/metadata/v1/InstanceInfo| grep -i ud`
if [ -n $result ]; then
 `logger Incoming VM reboot`
fi
