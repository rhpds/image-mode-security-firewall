#!/bin/sh
echo "Adding build-time firewall rule to Containerfile..." >> /tmp/progress.log

# Source environment variables if available
if [ -f /etc/profile.d/lab.sh ]; then
    . /etc/profile.d/lab.sh
fi

CONTAINERFILE="/root/examples/Containerfile"

# Check if Containerfile exists
if [ ! -f "$CONTAINERFILE" ]; then
    echo "FAIL: Containerfile not found at $CONTAINERFILE" >> /tmp/progress.log
    exit 1
fi

# Check if the directive is already present (as an active RUN line, not a comment)
if grep -qE '^[[:space:]]*RUN[[:space:]]+firewall-offline-cmd[[:space:]]+--add-port=8443/tcp' "$CONTAINERFILE"; then
    echo "Directive already present in Containerfile" >> /tmp/progress.log
else
    # Add the firewall-offline-cmd directive after the "systemctl enable firewalld" line
    sed -i '/RUN systemctl enable firewalld/a RUN firewall-offline-cmd --add-port=8443/tcp' "$CONTAINERFILE"

    if [ $? -ne 0 ]; then
        echo "FAIL: Could not modify Containerfile" >> /tmp/progress.log
        exit 1
    fi
    echo "Added firewall directive to Containerfile" >> /tmp/progress.log
fi

# Source GUID/DOMAIN if not set
if [ -z "$GUID" ] || [ -z "$DOMAIN" ]; then
    GUID=$(grep 'export GUID=' /etc/profile.d/lab.sh 2>/dev/null | cut -d= -f2 | tr -d '"')
    DOMAIN=$(grep 'export DOMAIN=' /etc/profile.d/lab.sh 2>/dev/null | cut -d= -f2 | tr -d '"')
fi

if [ -z "$GUID" ] || [ -z "$DOMAIN" ]; then
    echo "FAIL: GUID or DOMAIN not set" >> /tmp/progress.log
    exit 1
fi

# Build the image
echo "Building image registry-${GUID}.${DOMAIN}/base..." >> /tmp/progress.log
podman build --tag registry-${GUID}.${DOMAIN}/base --file "$CONTAINERFILE" /root/examples >> /tmp/progress.log 2>&1

if [ $? -ne 0 ]; then
    echo "FAIL: Image build failed" >> /tmp/progress.log
    exit 1
fi

# Push the image to the registry
echo "Pushing image to registry..." >> /tmp/progress.log
podman push registry-${GUID}.${DOMAIN}/base >> /tmp/progress.log 2>&1

if [ $? -ne 0 ]; then
    echo "FAIL: Image push failed" >> /tmp/progress.log
    exit 1
fi

echo "Image built and pushed successfully" >> /tmp/progress.log
echo "NOTE: Learner must run 'sudo bootc upgrade' and 'sudo systemctl reboot' on bootc-vm to deploy" >> /tmp/progress.log
exit 0
