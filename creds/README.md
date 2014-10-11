# creds: Example of credential set up for Ansible

## Introduction

This example tries to simplify the credential management for Ansible with the
following common set up:

  1. Each remote host has an agent user dedicated to remote logins by Ansible.
  2. Ansible logs in remote hosts via SSH using public key authentication with
     a common private key pulled from `ssh-agent` process.
  3. The agent user acquires root privilege using `sudo`.  Their login password
     should be unpredictable and unique among ones of all agent users.

Any sensitive information, including an SSH private key and login passwords for
all remote hosts can be stored in a single vault file encryped by Ansible and
safely shared by the DVCS like Git.  On the execution of `ansible-playbook`,
only one password is requested to decrypt it.

## [ssh-agent.py](callback_plugins/ssh-agent.py) callback plugin

This plugin registers an SSH private key defined in variable
`creds_ssh_private_key` with `ssh-agent` process, and defines another variable
`creds_ssh_public_key` which is suitable for `authorized_key` module used by
following tasks.

The plugin utilizes the `playbook_on_play_start` callback, so the key
registration takes place just before `ansible-playbook` performs any play in a
playbook.  Nothing happens if variable `creds_ssh_private_key` is undefined.

An SSH private key of `creds_ssh_private_key` should be non-encrypted, but the
variable might be defined in a vault file which is encrypted by Ansible.

The benefits of using this plugin are 1) you can save trouble of precedent
steps to prepare `ssh-agent` needed for non-interactive SSH public key
authentication, 2) you can safely preserve multiple credential information (SSH
private key, sudo passphrases, etc.) in a single vault file encrypted by
Ansible.

To use the plugin, put [ssh-agent.py](callback_plugins/ssh-agent.py) in the
directory `callback_plugins` relative to a playbook file, or configure plugin
paths in `ansible.cfg`.

## Examples

[creds_vault.yml](creds_vault.yml) shows variables to be defined in a vault
file which should be encrypted by 'ansible-vault'.  It also contains
definitions of `creds_user`, `creds_pass` and `creds_crypt` based on
`inventory_hostname`.

[creds_ansible.yml](creds_ansible.yml) defines special variables
`ansible_ssh_user` and `ansible_sudo_pass` referring `creds_user` and
`creds_pass` respectively to affect `ansible-playbook` behaviors.

[ping.yml](ping.yml) is a simple playbook to make use of them.  You should
always run `ansible-playbook` with `ssh-agent` for `ssh-agent.py` plugin to
work correctly, and `--ask-vault-pass` or `--vault-password-file` to provide a
password to decrypt the vault file.

```
$ ssh-agent ansible-playbook -i hosts --ask-vault-pass ping.yml

PLAY [all] ******************************************************************** 
Loading SSH private key 93:e2:fa:0a:a6:5c:c7:43:06:79:8d:ba:2d:c4:d8:01

GATHERING FACTS *************************************************************** 
ok: [host-a]
ok: [host-b]
ok: [host-c]
ok: [host-d]
...
```

[init-agent.yml](init-agent.yml) is to set up an agent user on remote hosts:
create `creds_user` with `creds_crypt` as encrypted login password, then put
`creds_ssh_public_key` in their `authorized_keys` file.  `mkpasswd` utility
should be available on the local host (On Debian based systems just run
`apt-get install whois` beforehand).  You will need to provide
`ansible-playbook` with alternate credential information using options like
`-u`, `-k`, `-K`.

```
$ ssh-agent ansible-playbook -i hosts --ask-vault-pass -k -K -u ubuntu init-agent.yml
SSH password: 
sudo password [defaults to SSH password]: 
...
``` 

[init-python.yml](init-python.yml) is to install Python packages on remote
hosts which is prerequisite for Ansible to work there.  This task will work
without python on remote hosts, but is limited to Debian and its derivatives.

```
ansible-playbook -i hosts -k -K -u ubuntu init-python.yml
```

[uninit.yml](uninit.yml) is to remove the agent user and uninstall Python
packages.  It's also limited to Debian and its derivatives.

```
ansible-playbook -i hosts -k -K -u ubuntu uninit.yml
```

## Internals

[ssh-agent.py](callback_plugins/ssh-agent.py) plugin uses
[Paramiko](http://www.paramiko.org) to interact `ssh-agent` process.  Paramiko
is one of the dependencies of current Ansible, so it's expected to be available
on the systems running Ansible.

Since the plugin exploits Paramiko's internal APIs, it might not work correctly
with certain versions of Paramiko/Ansible.

## Author

YAEGASHI Takeshi <<yaegashi@debian.org>>
