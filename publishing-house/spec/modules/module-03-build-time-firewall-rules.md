# Module 3: Baking Firewall Rules into the Containerfile

---

### Brief Overview

This module shifts from the ephemeral runtime approach to the preferred image mode practice: encoding firewall rules directly into the Containerfile so every image build produces a hardened, consistently configured host. Using the sample Containerfile already present in the lab environment, participants add the firewalld directives needed to open a port at build time, then validate that the Containerfile contains the correct instructions. This completes the mental model introduced in Module 1 and reinforced by the runtime contrast in Module 2.

### Audience and Time

- **Target personas:** Sysadmins and platform engineers
- **Prerequisites for this module:** Completion of Module 2 (Applying Firewall Rules on a Running Host)
- **Estimated duration:** 5 minutes

### Learning Objectives

- Locate and edit a Containerfile used to build a RHEL image mode (bootc) image
- Add firewall rule directives to the Containerfile so the rule is present in every image build
- Explain why build-time firewall configuration is the preferred approach for immutable, image-based systems

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Inspect the Sample Containerfile | 2 min |
| 2 | Add Firewall Rule Directives and Validate | 3 min |

### Detailed Steps

1. Open the in-browser terminal and navigate to the directory containing the sample Containerfile.
2. Inspect the existing Containerfile to understand its base image and current contents:
   ```
   cat Containerfile
   ```
3. Identify where in the Containerfile to add a `RUN` directive that configures firewalld (after the base image layer is established).
4. Add a `RUN` layer to the Containerfile that enables the firewalld service and opens the required port using `firewall-offline-cmd` (the appropriate tool for non-running firewalld in a container build context):
   ```
   RUN firewall-offline-cmd --add-port=8080/tcp
   ```
5. Save the updated Containerfile.
6. Review the updated file to confirm the directive is present in the correct position:
   ```
   cat Containerfile
   ```
7. Click the **Validate** button to confirm the lab environment detects the expected firewall directive in the Containerfile.

### Key Takeaways

- Containerfile `RUN` directives that use `firewall-offline-cmd` configure firewalld in a container build context where the daemon is not running.
- Rules baked into the Containerfile are present in every image built from it, making firewall policy repeatable, auditable, and immune to runtime drift.
- This build-time approach is the recommended practice for RHEL image mode (bootc) environments because it aligns with the immutable-OS model: desired state is declared in the image, not applied ad hoc at runtime.

### Infrastructure Notes

- A sample Containerfile must be pre-placed in the lab environment and accessible from the in-browser terminal.
- The Containerfile should use a RHEL image mode (bootc-compatible) base image so the context is authentic.
- The validation script checks that the Containerfile contains the correct `firewall-offline-cmd` directive for the expected port; it does not perform an actual container build.
- This module includes a solve/validate button per the Zero-Touch lab assessment strategy.
