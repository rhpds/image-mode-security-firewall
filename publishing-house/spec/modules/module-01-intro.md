# Module 1: Introduction to Firewall Rules in Image Mode

---

### Brief Overview

RHEL image mode (bootc) treats the operating system as an immutable container image: the running filesystem is read-only between reboots, and changes are delivered as new image builds rather than in-place package updates. This immutability changes the rules for firewall management. Before touching the command line, participants learn why runtime firewall changes behave differently in an image-based system and why build-time hardening is the preferred long-term approach. The module sets the conceptual stage for the hands-on work in Modules 2 and 3.

### Audience and Time

- **Target personas:** Sysadmins and platform engineers
- **Prerequisites for this module:** Basic Linux CLI proficiency; familiarity with RHEL or a similar Linux distribution; no prior image mode or bootc experience required
- **Estimated duration:** 5 minutes

### Learning Objectives

- Explain what RHEL image mode (bootc) is and how it differs from a traditionally managed RHEL system
- Describe how firewalld operates on a running image mode host
- Distinguish between runtime firewall changes (ephemeral) and build-time firewall rules (durable across image updates)

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | What is RHEL Image Mode? | 2 min |
| 2 | Firewall Management in Immutable Systems | 3 min |

### Detailed Steps

1. Read the brief overview page explaining what a bootc-based image mode host is.
2. Review the diagram showing the difference between a traditional RHEL host (mutable, in-place changes) and an image mode host (immutable, image-based updates).
3. Note that firewalld is present and running on the pre-provisioned image mode host, just as on a conventional RHEL host.
4. Read the explanation of why runtime firewall changes are ephemeral on an image mode host: a new image deployment can overwrite the running configuration.
5. Review the summary comparison table contrasting runtime vs. build-time firewall rule management.

### Key Takeaways

- RHEL image mode (bootc) treats the OS as an immutable container image; changes survive only if baked into the next image build.
- firewalld runs normally on image mode hosts, but runtime-only changes risk being lost when a new image is deployed.
- Build-time firewall rules baked into the Containerfile are the durable, repeatable approach for immutable systems.

### Infrastructure Notes

No hands-on actions in this module. The pre-deployed RHEL image mode host must be accessible at lab start so participants can observe it in later modules, but this module is reading/conceptual only.
