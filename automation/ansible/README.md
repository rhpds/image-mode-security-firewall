# `automation`

Starter Ansible collection for this project's custom automation — the base to build your
own roles on top of. It ships with a single no-op `example` role (`roles/example/`) so
the collection is valid and installable from the start.

This collection is never published to Ansible Galaxy. It's referenced straight from this
project's git repository. See the [Custom Ansible Automation](https://rhpds.github.io/rhdp-publishing-house/user/custom-automation/)
guide for the full walkthrough, including how to wire it into an AgnosticV
`requirements_content`.

## Structure

```
automation/ansible/
├── galaxy.yml
├── README.md
├── meta/
│   └── runtime.yml
└── roles/
    └── example/
        ├── README.md
        ├── defaults/
        │   └── main.yml
        ├── meta/
        │   └── main.yml
        └── tasks/
            └── main.yml
```

## Adding a role

```bash
ansible-galaxy role init --init-path roles/ my_role_name
```

Then reference it by its fully qualified name once the collection is installed:

```yaml
- name: Run my_role_name
  ansible.builtin.include_role:
    name: image_mode_security_firewall.automation.my_role_name
```

## Testing locally

Install the collection straight from your working tree to confirm it's structured
correctly before pushing:

```bash
ansible-galaxy collection install . --force
```
