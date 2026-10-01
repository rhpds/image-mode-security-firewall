#!/bin/sh
echo "Validating module-02" >> /tmp/progress.log

# Source environment or glob the key
if [ -f /etc/profile.d/lab.sh ]; then
    . /etc/profile.d/lab.sh
fi

KEY=$(ls /root/.ssh/*key 2>/dev/null | head -1)
if [ -z "$KEY" ]; then
    echo "FAIL: SSH key not found"
    echo "HINT: Cannot connect to bootc-vm. Contact lab support."
    exit 1
fi

# Check that port 8080/tcp is open on the bootc-vm
# The participant opened this with: sudo firewall-cmd --add-port=8080/tcp
PORTS=$(ssh -i "$KEY" -o StrictHostKeyChecking=no core@bootc-vm 'sudo firewall-cmd --list-ports' 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "FAIL: Cannot connect to bootc-vm"
    echo "HINT: SSH connection failed. Wait a moment and try navigating forward again."
    exit 1
fi

echo "$PORTS" | grep -q '8080/tcp'
if [ $? -ne 0 ]; then
    echo "FAIL: Port 8080/tcp is not open on bootc-vm"
    echo "HINT: Run 'sudo firewall-cmd --add-port=8080/tcp' on the Bootc VM terminal"
    exit 1
fi

echo "PASS: module-02 objectives verified (port 8080/tcp open)"
exit 0
