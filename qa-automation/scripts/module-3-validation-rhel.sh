#!/bin/sh
echo "Validating module-03" >> /tmp/progress.log

# Source environment variables if available
if [ -f /etc/profile.d/lab.sh ]; then
    . /etc/profile.d/lab.sh
fi

CONTAINERFILE="/root/examples/Containerfile"

# Find SSH key to connect to bootc-vm
KEY=$(ls /root/.ssh/*key 2>/dev/null | head -1)
if [ -z "$KEY" ]; then
    echo "FAIL: SSH key not found"
    echo "HINT: Cannot connect to bootc-vm. Contact lab support."
    exit 1
fi

# Check 1: Containerfile contains the firewall-offline-cmd directive (as active RUN, not comment)
if [ ! -f "$CONTAINERFILE" ]; then
    echo "FAIL: Containerfile not found at $CONTAINERFILE"
    echo "HINT: The Containerfile should be at /root/examples/Containerfile"
    exit 1
fi

if ! grep -qE '^[[:space:]]*RUN[[:space:]]+firewall-offline-cmd[[:space:]]+--add-port=8443/tcp' "$CONTAINERFILE"; then
    echo "FAIL: Containerfile does not contain an active RUN firewall-offline-cmd directive for port 8443/tcp"
    echo "HINT: Edit ~/examples/Containerfile and add: RUN firewall-offline-cmd --add-port=8443/tcp"
    exit 1
fi

# Check 2: Image was built and exists locally
# Source GUID/DOMAIN if not set
if [ -z "$GUID" ] || [ -z "$DOMAIN" ]; then
    GUID=$(grep 'export GUID=' /etc/profile.d/lab.sh 2>/dev/null | cut -d= -f2 | tr -d '"')
    DOMAIN=$(grep 'export DOMAIN=' /etc/profile.d/lab.sh 2>/dev/null | cut -d= -f2 | tr -d '"')
fi

if [ -n "$GUID" ] && [ -n "$DOMAIN" ]; then
    podman images --format '{{.Repository}}:{{.Tag}}' | grep -q "registry-${GUID}.${DOMAIN}/base:latest"
    if [ $? -ne 0 ]; then
        echo "FAIL: Image registry-${GUID}.${DOMAIN}/base not found"
        echo "HINT: Rebuild with: podman build --tag registry-${GUID}.${DOMAIN}/base --file ~/examples/Containerfile ~/examples"
        exit 1
    fi
else
    # Fallback: check for any image with 'base'
    podman images --format '{{.Repository}}:{{.Tag}}' | grep -q 'base'
    if [ $? -ne 0 ]; then
        echo "FAIL: No rebuilt image found"
        echo "HINT: Rebuild the image"
        exit 1
    fi
fi

# Check 3 & 4: On bootc-vm, verify 8443/tcp is open and 8080/tcp is NOT open
PORTS=$(ssh -i "$KEY" -o StrictHostKeyChecking=no core@bootc-vm 'sudo firewall-cmd --list-ports' 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "FAIL: Cannot connect to bootc-vm"
    echo "HINT: VM may still be rebooting. Wait 1-2 minutes and try again."
    exit 1
fi

echo "$PORTS" | grep -q '8443/tcp'
if [ $? -ne 0 ]; then
    echo "FAIL: Port 8443/tcp is not open on bootc-vm"
    echo "HINT: After editing, rebuild and push the image, then on bootc-vm run 'sudo bootc upgrade' and 'sudo systemctl reboot'"
    exit 1
fi

echo "$PORTS" | grep -q '8080/tcp'
if [ $? -eq 0 ]; then
    echo "FAIL: Port 8080/tcp is still open on bootc-vm"
    echo "HINT: The runtime-only change from module-02 should be gone after reboot. Reboot bootc-vm with 'sudo systemctl reboot'"
    exit 1
fi

echo "PASS: module-03 objectives verified (8443/tcp open from image, 8080/tcp gone)" >> /tmp/progress.log
exit 0
