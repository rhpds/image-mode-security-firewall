#!/bin/sh
echo "Validating module-03" >> /tmp/progress.log

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

# Check 1: Containerfile contains the firewall-offline-cmd directive
if [ ! -f /root/examples/Containerfile ]; then
    echo "FAIL: Containerfile not found at /root/examples/Containerfile"
    echo "HINT: The Containerfile should exist. Contact lab support."
    exit 1
fi

# Anchor on an uncommented RUN directive. The delivered Containerfile ships the
# same text as an instructional comment ("#   RUN firewall-offline-cmd ..."), so a
# plain substring grep would match before the participant does anything. Requiring a
# line that begins with RUN (ignoring leading whitespace) confirms the real edit.
grep -qE '^[[:space:]]*RUN[[:space:]]+firewall-offline-cmd[[:space:]]+--add-port=8443/tcp' /root/examples/Containerfile
if [ $? -ne 0 ]; then
    echo "FAIL: Containerfile does not contain an active RUN firewall-offline-cmd directive for port 8443/tcp"
    echo "HINT: Edit ~/examples/Containerfile and add the line: RUN firewall-offline-cmd --add-port=8443/tcp"
    exit 1
fi

# Check 2: Image was built and exists
# Source GUID/DOMAIN for image ref check (may not be set in non-login shell)
if [ -z "$GUID" ] || [ -z "$DOMAIN" ]; then
    # Try to extract from /etc/profile.d/lab.sh
    GUID=$(grep 'export GUID=' /etc/profile.d/lab.sh 2>/dev/null | cut -d= -f2)
    DOMAIN=$(grep 'export DOMAIN=' /etc/profile.d/lab.sh 2>/dev/null | cut -d= -f2)
fi

# podman images check (we know the image ref from setup)
if [ -n "$GUID" ] && [ -n "$DOMAIN" ]; then
    podman images --format '{{.Repository}}:{{.Tag}}' | grep -q "registry-${GUID}.${DOMAIN}/base:latest"
    if [ $? -ne 0 ]; then
        echo "FAIL: Image registry-${GUID}.${DOMAIN}/base not found"
        echo "HINT: Rebuild with: podman build --tag registry-${GUID}.${DOMAIN}/base --file ~/examples/Containerfile ~/examples"
        exit 1
    fi
else
    # Fallback: just check that some image with 'base' exists
    podman images --format '{{.Repository}}:{{.Tag}}' | grep -q 'base'
    if [ $? -ne 0 ]; then
        echo "FAIL: No rebuilt image found"
        echo "HINT: Rebuild the image with: podman build --tag registry-{guid}.{domain}/base --file ~/examples/Containerfile ~/examples"
        exit 1
    fi
fi

# Check 3 & 4: On bootc-vm, verify 8443/tcp is open and 8080/tcp is NOT open
# This proves the rule came from the image (8443) and the runtime change was lost (8080)
PORTS=$(ssh -i "$KEY" -o StrictHostKeyChecking=no core@bootc-vm 'sudo firewall-cmd --list-ports' 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "FAIL: Cannot connect to bootc-vm"
    echo "HINT: VM may still be rebooting. Wait 1-2 minutes and navigate forward again."
    exit 1
fi

echo "$PORTS" | grep -q '8443/tcp'
if [ $? -ne 0 ]; then
    echo "FAIL: Port 8443/tcp is not open on bootc-vm"
    echo "HINT: After editing the Containerfile, rebuild (podman build), push (podman push), then on the Bootc VM run 'sudo bootc upgrade' and 'sudo systemctl reboot'"
    exit 1
fi

echo "$PORTS" | grep -q '8080/tcp'
if [ $? -eq 0 ]; then
    echo "FAIL: Port 8080/tcp is still open on bootc-vm"
    echo "HINT: The runtime-only change from module-02 should be gone after reboot. Did you reboot the bootc-vm? Run 'sudo systemctl reboot' on the Bootc VM terminal."
    exit 1
fi

echo "PASS: module-03 objectives verified (8443/tcp open from image, 8080/tcp gone)"
exit 0
