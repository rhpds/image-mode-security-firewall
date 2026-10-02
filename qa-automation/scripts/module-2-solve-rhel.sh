#!/bin/sh
echo "Opening port 8080/tcp at runtime on bootc-vm..." >> /tmp/progress.log

# Source environment variables if available
if [ -f /etc/profile.d/lab.sh ]; then
    . /etc/profile.d/lab.sh
fi

# Find SSH key to connect to bootc-vm
KEY=$(ls /root/.ssh/*key 2>/dev/null | head -1)
if [ -z "$KEY" ]; then
    echo "FAIL: SSH key not found" >> /tmp/progress.log
    echo "HINT: Cannot connect to bootc-vm. Contact lab support."
    exit 1
fi

# Open port 8080/tcp on the bootc-vm (runtime only, no --permanent)
ssh -i "$KEY" -o StrictHostKeyChecking=no -o ControlPath=none core@bootc-vm 'sudo firewall-cmd --add-port=8080/tcp' >> /tmp/progress.log 2>&1

if [ $? -ne 0 ]; then
    echo "FAIL: Could not add port 8080/tcp to firewall on bootc-vm" >> /tmp/progress.log
    exit 1
fi

echo "Port 8080/tcp opened successfully on bootc-vm" >> /tmp/progress.log
exit 0
