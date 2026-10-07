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
    sed -i '/^RUN systemctl enable firewalld$/a RUN firewall-offline-cmd --add-port=8443/tcp' "$CONTAINERFILE"

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

# Rebuild the bootc-vm from the updated image
echo "Rebuilding bootc-vm disk image from updated container image..." >> /tmp/progress.log

BIB=registry.redhat.io/rhel10/bootc-image-builder:10.1

# Destroy and undefine the existing bootc-vm
virsh destroy bootc-vm 2>/dev/null >> /tmp/progress.log
virsh undefine bootc-vm 2>/dev/null >> /tmp/progress.log

# Remove old qcow2 output
rm -rf /root/qcow2 2>/dev/null

# Use bootc-image-builder to create new qcow2 from the updated image
cd /root
podman run --rm --privileged --security-opt label=type:unconfined_t \
  --volume ./config.toml:/config.toml \
  --volume /var/lib/containers/storage:/var/lib/containers/storage \
  --volume .:/output \
  ${BIB} \
  --type qcow2 \
  registry-${GUID}.${DOMAIN}/base >> /tmp/progress.log 2>&1

if [ $? -ne 0 ]; then
    echo "FAIL: bootc-image-builder failed" >> /tmp/progress.log
    exit 1
fi

# Copy the new disk image
cp -f /root/qcow2/disk.qcow2 /var/lib/libvirt/images/bootc-vm.qcow2

if [ $? -ne 0 ]; then
    echo "FAIL: Failed to copy qcow2 disk image" >> /tmp/progress.log
    exit 1
fi

# Recreate the VM with the new disk image
virt-install --name bootc-vm \
  --disk /var/lib/libvirt/images/bootc-vm.qcow2 \
  --import --memory 4096 --graphics none \
  --osinfo rhel10-unknown --noautoconsole --noreboot >> /tmp/progress.log 2>&1

if [ $? -ne 0 ]; then
    echo "FAIL: virt-install failed" >> /tmp/progress.log
    exit 1
fi

# Start the VM
virsh start bootc-vm >> /tmp/progress.log 2>&1

if [ $? -ne 0 ]; then
    echo "FAIL: Failed to start bootc-vm" >> /tmp/progress.log
    exit 1
fi

echo "Waiting for bootc-vm to come up..." >> /tmp/progress.log
sleep 10

# Wait for the VM to be accessible (retry SSH for up to 2 minutes)
KEY=$(ls /root/.ssh/*key 2>/dev/null | head -1)
if [ -z "$KEY" ]; then
    echo "FAIL: SSH key not found" >> /tmp/progress.log
    exit 1
fi

RETRY_COUNT=0
MAX_RETRIES=24  # 24 * 5 seconds = 2 minutes

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if ssh -i "$KEY" -o StrictHostKeyChecking=no -o ControlPath=none -o ConnectTimeout=5 core@bootc-vm 'echo ok' >> /tmp/progress.log 2>&1; then
        echo "bootc-vm is up and accessible" >> /tmp/progress.log
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 5
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "FAIL: bootc-vm did not come up after deployment" >> /tmp/progress.log
    exit 1
fi

echo "Module 3 solve complete: VM redeployed with updated image containing build-time firewall rule" >> /tmp/progress.log
exit 0
