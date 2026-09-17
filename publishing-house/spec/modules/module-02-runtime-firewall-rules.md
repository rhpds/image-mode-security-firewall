# Module 2: Applying Firewall Rules on a Running Host

---

### Brief Overview

This module gives participants hands-on experience with firewalld on a live RHEL image mode host. Using an in-browser terminal connected to the pre-provisioned bootc-based system, participants add a firewall rule to the active zone, verify it is in effect, and then observe what happens to that rule across the image mode boundary. The goal is not just to show how to use firewalld, but to make the ephemerality of runtime changes concrete before Module 3 introduces the build-time alternative.

### Audience and Time

- **Target personas:** Sysadmins and platform engineers
- **Prerequisites for this module:** Completion of Module 1 (Introduction to Firewall Rules in Image Mode)
- **Estimated duration:** 5 minutes

### Learning Objectives

- Apply a firewall rule to a running RHEL image mode host using firewalld
- Verify that the rule is active in the correct firewalld zone
- Recognize that runtime-only firewall changes are not guaranteed to survive an image update

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Open a Port with firewall-cmd | 3 min |
| 2 | Verify the Active Rule | 2 min |

### Detailed Steps

1. Open the in-browser terminal connected to the pre-provisioned RHEL image mode host.
2. Check the current active firewalld zone and its open services/ports:
   ```
   firewall-cmd --get-active-zones
   firewall-cmd --list-all
   ```
3. Add a rule to open a specific port (for example, TCP 8080) in the active zone at runtime:
   ```
   firewall-cmd --add-port=8080/tcp
   ```
4. Confirm the port is now listed in the active zone:
   ```
   firewall-cmd --list-ports
   ```
5. Click the **Validate** button to confirm the lab environment detects the expected port is open in the active firewalld zone.
6. Read the inline callout explaining that this change is runtime-only: it was not passed `--permanent`, and even a permanent runtime change could be overwritten when a new bootc image is deployed.

### Key Takeaways

- `firewall-cmd` works the same way on an image mode host as on a conventional RHEL host — the runtime experience is familiar.
- Runtime firewall changes (without `--permanent`) survive only until the service restarts; even permanent changes can be overwritten by a new image deployment.
- To make firewall rules durable in an image mode workflow, they must be baked into the image at build time.

### Infrastructure Notes

- A RHEL image mode (bootc-based) host must be pre-provisioned and reachable via in-browser terminal at lab start.
- firewalld must be active on the host.
- The validation script checks that the expected port (e.g., 8080/tcp) is present in the active firewalld zone output; it does not require a `--permanent` flag to be set.
- This module includes a solve/validate button per the Zero-Touch lab assessment strategy.
