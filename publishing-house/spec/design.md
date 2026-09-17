# Securing RHEL Image Mode: Firewall Rules at Build Time

## Overview

This lab introduces firewall rule management for RHEL image mode (bootc) environments. Participants explore two complementary approaches — applying rules at runtime on a running image mode host, and baking rules directly into the Containerfile at build time — to understand why build-time hardening is the preferred practice for immutable, image-based systems. The lab is intentionally concise: three short modules that contrast the ephemeral runtime approach with the durable build-time approach, leaving participants with a clear mental model they can apply immediately.

## Target Audience

- **Role:** Sysadmins and platform engineers
- **Experience level:** Beginner
- **What they already know:** Linux CLI basics, familiarity with RHEL fundamentals
- **What they don't know:** RHEL image mode (bootc) concepts, managing firewall rules in image-based deployments

## Prerequisites

- Basic Linux command-line proficiency
- Familiarity with RHEL or a similar Linux distribution
- No prior image mode or bootc experience required
- Prerequisites are trust-based — no automated validation at lab start

## Learning Objectives

1. Apply firewall rules to a running RHEL image mode host using firewalld
2. Bake firewall rules into a Containerfile as part of a build-time image hardening workflow

## Content Type

Lab (hands-on)

## Products & Technologies

- Red Hat Enterprise Linux (image mode / bootc)
- firewalld

## Module Map

| Module | Title | Duration |
|--------|-------|----------|
| 1 | Introduction to Firewall Rules in Image Mode | 5 min |
| 2 | Applying Firewall Rules on a Running Host | 5 min |
| 3 | Baking Firewall Rules into the Containerfile | 5 min |
| — | **Total hands-on** | **15 min** |
| — | **Total lab** | **~15 min** |

## Difficulty Level

Beginner

## Environment

**Learner view:** A pre-deployed RHEL image mode host is available at lab start. Participants have terminal access and can run firewalld commands, inspect the running configuration, and modify the Containerfile used to produce the image.

**Automation needed:** Yes — a RHEL image mode host (bootc-based) must be provisioned and accessible via an in-browser terminal at lab start. A sample Containerfile must be present in the environment.

## Infrastructure Requirements

- **Cloud provider:** TBD — confirmed in infrastructure phase
- **Cluster type:** TBD — confirmed in infrastructure phase
- **OCP version:** TBD — confirmed in infrastructure phase
- **Topology:** TBD — confirmed in infrastructure phase
- **Sizing:** TBD — confirmed in infrastructure phase
- **Automation approach:** TBD — confirmed in infrastructure phase
- **AI/MaaS:** TBD — confirmed in infrastructure phase
- **External services:** TBD — confirmed in infrastructure phase
- **AAP version:** TBD — confirmed in infrastructure phase
- **Non-GA products:** TBD — confirmed in infrastructure phase

## Assessment Strategy

This is a Zero-Touch lab. Each hands-on module includes a solve/validate button:

- **Module 2:** Validates that the specified firewall rule is active on the running host (e.g., the expected port/service is open in the active firewalld zone)
- **Module 3:** Validates that the Containerfile includes the correct firewall rule directives and that a rebuild would produce a hardened image
