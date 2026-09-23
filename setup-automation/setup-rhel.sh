#!/bin/bash
set -x
USER=rhel

echo "Adding wheel" > /root/post-run.log
usermod -aG wheel rhel

echo "Setup build host for image-mode security-firewall lab" > /tmp/progress.log
chmod 666 /tmp/progress.log

# Base image the lab builds on. The bootc guest boots from an image derived from
# this base with firewalld installed and enabled, so Module 2 can manage firewall
# rules on a running image mode host.
BOOTC_RHEL_VER=10.1
BASE=registry.redhat.io/rhel10/rhel-bootc:${BOOTC_RHEL_VER}
BIB=registry.redhat.io/rhel10/bootc-image-builder:${BOOTC_RHEL_VER}
IMAGE_REF=registry-${GUID}.${DOMAIN}/base

# Set up libvirt and name resolution for the nested guest
systemctl enable --now libvirtd
sed -i 's/hosts:\s\+ files/& libvirt libvirt_guest/' /etc/nsswitch.conf

# Set up registry authentication so base images pull
mkdir -p ~/.config/containers
cat <<EOF> ~/.config/containers/auth.json
{
    "auths": {
      "registry.redhat.io": {
        "auth": "${REGISTRY_PULL_TOKEN}"
      }
    }
  }
EOF

# Pull needed images
podman pull $BASE
podman pull $BIB

# Set up SSL for a fully functioning local registry (bootc/podman reject
# untrusted registries, so a real ZeroSSL cert is required — not self-signed).
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
dnf install -y certbot

CERT_DIR="/etc/letsencrypt/live/registry-${GUID}.${DOMAIN}"
CERT_MAX_RETRIES=3
CERT_RETRY=0
while [ $CERT_RETRY -lt $CERT_MAX_RETRIES ]; do
    set +x  # suppress xtrace around credential use
    certbot certonly --eab-kid "${ZEROSSL_EAB_KEY_ID}" --eab-hmac-key "${ZEROSSL_HMAC_KEY}" --server "https://acme.zerossl.com/v2/DV90" --standalone --preferred-challenges http -d registry-"${GUID}"."${DOMAIN}" --non-interactive --agree-tos -m trackbot@instruqt.com -v
    rm -f /var/log/letsencrypt/letsencrypt.log
    set -x

    if [ -f "$CERT_DIR/fullchain.pem" ] && [ -f "$CERT_DIR/privkey.pem" ]; then
        echo "SSL certificates obtained successfully" >> /tmp/progress.log
        break
    fi

    CERT_RETRY=$((CERT_RETRY + 1))
    echo "Certificate attempt $CERT_RETRY of $CERT_MAX_RETRIES failed, retrying in 15 seconds..." >> /tmp/progress.log
    sleep 15
done

if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
    echo "FATAL: Failed to obtain SSL certificates after $CERT_MAX_RETRIES attempts" >> /tmp/progress.log
    echo "FATAL: Registry cannot start without TLS certificates. Aborting setup." >> /tmp/progress.log
    exit 1
fi

# Run a local registry (no auth) with the provided certs
podman run --privileged -d \
  --name registry \
  -p 443:5000 \
  -v /etc/letsencrypt/live/registry-"${GUID}"."${DOMAIN}"/fullchain.pem:/certs/fullchain.pem \
  -v /etc/letsencrypt/live/registry-"${GUID}"."${DOMAIN}"/privkey.pem:/certs/privkey.pem \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/fullchain.pem \
  -e REGISTRY_HTTP_TLS_KEY=/certs/privkey.pem \
  quay.io/mmicene/registry:2

# Validate registry container is running
sleep 5
if ! podman ps --filter name=registry --format '{{.Names}}' | grep -q registry; then
    echo "FATAL: Registry container failed to start. Checking logs:" >> /tmp/progress.log
    podman logs registry >> /tmp/progress.log 2>&1
    exit 1
fi

# Validate registry is responding (401 = auth required, 200 = ok — either proves TLS works)
REG_MAX_RETRIES=5
REG_RETRY=0
while [ $REG_RETRY -lt $REG_MAX_RETRIES ]; do
    HTTP_CODE=$(curl -sk -o /dev/null -w '%{http_code}' https://registry-${GUID}.${DOMAIN}/v2/ 2>/dev/null)
    if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "Registry is responding (HTTP $HTTP_CODE)" >> /tmp/progress.log
        break
    fi
    REG_RETRY=$((REG_RETRY + 1))
    echo "Registry not responding yet (HTTP $HTTP_CODE), retry $REG_RETRY of $REG_MAX_RETRIES..." >> /tmp/progress.log
    sleep 5
done

if [ $REG_RETRY -eq $REG_MAX_RETRIES ]; then
    echo "FATAL: Registry is not responding after $REG_MAX_RETRIES attempts. Aborting setup." >> /tmp/progress.log
    podman logs registry >> /tmp/progress.log 2>&1
    exit 1
fi

# Name-based resolution for internal IPs (10.0.2.2 is the libvirt NAT gateway,
# so the nested guest reaches the host's registry by name).
echo "10.0.2.2 rhel.${GUID}.${DOMAIN}" >> /etc/hosts
echo "10.0.2.2 registry-${GUID}.${DOMAIN}" >> /etc/hosts
mkdir -p ~/etc
cp /etc/hosts ~/etc/hosts

# Generate SSH key used to log in to the nested guest as 'core'
ssh-keygen -t ed25519 -f ~/.ssh/${GUID}key -N '' -C "Lab SSH Key"

# Create config.toml for bootc-image-builder (defines the guest 'core' user)
cat <<EOF> /root/config.toml
[[customizations.user]]
name = "core"
password = "redhat"
groups = ["wheel"]
key = "$(cat ~/.ssh/${GUID}key.pub)"
EOF

# Build the image the guest boots. firewalld is installed and enabled so the
# running host presents a familiar, active firewall for Module 2. NOTE: no
# build-time port rule is baked in here on purpose — that is exactly what the
# participant learns to add in Module 3.
cd ~
CTX=~/image-context
mkdir -p $CTX
cat <<EOF> $CTX/Containerfile
FROM ${BASE}
RUN dnf -y install firewalld && dnf clean all
RUN systemctl enable firewalld
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel-nopasswd && chmod 0440 /etc/sudoers.d/wheel-nopasswd
RUN bootc container lint
EOF
podman build --file $CTX/Containerfile --tag ${IMAGE_REF} $CTX
podman push ${IMAGE_REF}

# Convert the pushed image to a qcow2 and boot it as a nested libvirt guest
podman run --rm --privileged --security-opt label=type:unconfined_t \
  --volume ./config.toml:/config.toml \
  --volume /var/lib/containers/storage:/var/lib/containers/storage \
  --volume .:/output \
  ${BIB} \
  --type qcow2 \
  ${IMAGE_REF}

cp qcow2/disk.qcow2 /var/lib/libvirt/images/bootc-vm.qcow2

virt-install --name bootc-vm \
  --disk /var/lib/libvirt/images/bootc-vm.qcow2 \
  --import --memory 4096 --graphics none \
  --osinfo rhel10-unknown --noautoconsole --noreboot

virsh start bootc-vm

# Wait-then-SSH script the wetty_bootc_vm terminal runs
cat <<'SCRIPT'> /root/.wait_for_bootc_vm.sh
#!/bin/bash
echo "Waiting for VM 'bootc-vm' to be running..."
VM_NAME=bootc-vm
while true; do
    VM_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null)
    if [[ "$VM_STATE" == "running" ]]; then
        break
    fi
    sleep 10
done
echo "Waiting for SSH to be available..."
while true; do
    if ping -c 1 -W 1 ${VM_NAME} &>/dev/null; then
        break
    fi
    sleep 5
done
ssh -i ~/.ssh/${GUID}key -o StrictHostKeyChecking=no core@${VM_NAME}
SCRIPT

chmod u+x /root/.wait_for_bootc_vm.sh

# Deliver the participant's build files (examples/Containerfile, config.toml)
# from the lab's own git repo via sparse checkout. The examples/Containerfile is
# the sample the participant edits in Module 3.
cd ~
EXAMPLE=examples
TMPDIR=/tmp/lab
git clone --single-branch --branch ${GIT_BRANCH:-main} --no-checkout --depth=1 --filter=tree:0 ${GIT_REPO} $TMPDIR
git -C $TMPDIR sparse-checkout set --no-cone /${EXAMPLE}
git -C $TMPDIR checkout
if [ -d $TMPDIR/${EXAMPLE} ]; then
    cp -r $TMPDIR/${EXAMPLE} /root/${EXAMPLE}
    mv $TMPDIR/${EXAMPLE} ${EXAMPLE}
fi
rm -rf $TMPDIR

mkdir -p ~/scratch

# Export environment variables for interactive shells
echo "export GUID=${GUID}" >> /etc/profile.d/lab.sh
echo "export DOMAIN=${DOMAIN}" >> /etc/profile.d/lab.sh

echo "Image-mode security-firewall lab setup complete" >> /tmp/progress.log
