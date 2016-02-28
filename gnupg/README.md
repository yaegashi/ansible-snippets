# Ansible GnuPG Integration (for SSH keys, vault passphrases and others)

## Introduction

[ansible-gpg-agent.sh](ansible-gpg-agent.sh) and
[ansible-gpg-file.sh](ansible-gpg-file.sh) are shell scripts
which help you to integrate GnuPG (gpg) and its agent (gpg-agent)
into Ansible's SSH public key authentication and vault encryption/decryption.

gpg-agent could hold SSH private keys much like ssh-agent does,
as well as cache credentials for encryption/decryption in a secure way.
With gpg-agent Ansible could make frequent SSH connections
and vault content decryptions without asking users for passphrases every time.

This document would show you how those scripts are meant to be used,
along with recommended GnuPG set up and demonstration.

## Scripts

### ansible-gpg-agent.sh

[ansible-gpg-agent.sh](ansible-gpg-agent.sh)
is a shell script setting up a gpg-agent process,
which is dedicated for Ansible related tasks you perform later.

The basic functionality of the script is 1) to ensure that
there's a single instance of the agent running in the system,
2) to set up environment variables needed to access that agent.

The agent instance is persisted as a daemon process
and live across multiple command invocations and user sessions.
The running instance is identified by `~/.gnupg/.ansible-gpg-agent-info`
by default.

The most common usage would be to execute commands passed as arguments
under gpg-agent environment prepared by the script:

    $ ./ansible-gpg-agent.sh -- ssh-add *.id_rsa
    Enter passphrase for key1.id_rsa: 
    Identity added: key1.id_rsa (key1.id_rsa)
    Enter passphrase for key2.id_rsa: 
    Identity added: key2.id_rsa (key2.id_rsa)
    Enter passphrase for key3.id_rsa: 
    Identity added: key3.id_rsa (key3.id_rsa)
    $ ./ansible-gpg-agent.sh -- ssh-add -l
    2048 cb:0f:5b:e9:0f:e6:83:0c:50:17:e3:b8:17:2f:a1:50 key1.id_rsa (RSA)
    2048 1a:55:6a:4e:ae:5b:34:27:32:0b:e1:49:95:30:5a:e6 key2.id_rsa (RSA)
    2048 c8:f7:fd:e7:b1:fe:f9:ba:90:be:32:a1:0a:c2:2b:26 key3.id_rsa (RSA)

Note that you need to prepend `--` to every command
in order to pass correct options, like `-l` shown above.

The script could also provide snippets for interactive shells
to set up aliases to run ansible commands with the agent support.
You could simply eval the output from `ansible-gpg-agent -a`
in your `.bashrc`:

    eval $(/path/to/ansible-gpg-agent -a)

And you would get handy aliases:

    $ alias
    alias ansible='/path/to/ansible-gpg-agent.sh -- ansible'
    alias ansible-playbook='/path/to/ansible-gpg-agent.sh -- ansible-playbook'
    alias ansible-vault='/path/to/ansible-gpg-agent.sh -- ansible-vault'

Using those aliases you can easily isolate gpg-agent for Ansible tasks
(that would be often shared by a team using VCS)
from your personal gpg-agent/ssh-agent environment for other tasks.

### ansible-gpg-file.sh

[ansible-gpg-file.sh](ansible-gpg-file.sh)
is a shell script with secure content enrypted by GnuPG embedded in itself.
When executed without any arguments,
the script just prints out the plain text content by running GnuPG on itself.
User would have a prompt asking for a passphrase for decryption.

It's suitable for being specified with Ansible options like
`--vault-password-file` (the most common use case), `--inventory` and others.
When those options are specified with an executable file like this script,
Ansible will not read its content but execute it,
and take output from it for the options.

The script also provides an easy way to replace embedded content with new one,
however, it's left to users to prepare encrypted content to embed
by running GnuPG for themselves.
It might be as complex as using public key encryption
to sign content and specify limited users who could decrypt it,
or as simple as using a symmetric cipher like the following example:

    $ echo secret-passphrase | gpg -ac | /path/to/ansible-gpg-file.sh -ir -
    $ /path/to/ansible-gpg-file.sh
    secret-passphrase

Note that the pipeline shown above won't work
with GnuPG v2 and pinentry-curses combination
because they fail to read both content and passphrase from stdin.
If it's the case with you, you should create intermediate files like this:

    $ echo secret-passphrase > secret.txt
    $ gpg -ac secret.txt
    $ /path/to/ansible-gpg-file.sh -ir secret.txt.asc
    $ /path/to/ansible-gpg-file.sh
    secret-passphrase

Also note that embedded content must be in ASCII-armored format,
so you must always specify `-a` option to GnuPG command for encryption.

It's quite useful to specify ansible-gpg-file.sh for `--vault-password-file`
in gpg-agent environment prepared by ansible-gpg-agent.sh.
Once the correct passphrase for vault password decryption is provided,
it won't again ask users for it afterward.
You can implicitly specify that option in [ansible.cfg](ansible.cfg) or
environment variable `ANSIBLE_VAULT_PASSWORD_FILE`.
See [documentation](http://docs.ansible.com/ansible/intro_configuration.html)
or [source](https://github.com/ansible/ansible/blob/devel/lib/ansible/constants.py)
for those kinds of Ansible configurations.

You might want to make copies of the script and
give them more content-descriptive names.
For example you could have [vaultpass](vaultpass) and
run `ansible-playbook --vault-password-file=/path/to/vaultpass`.
And you could safely share it in a VCS repository along with vault files.

### Script Configuration

You can control the scripts by setting the following environment variables:

|Variable|Default|Description|
|---|---|---|
|`ANSIBLE_GPG`|`gpg2`|Command invoked for `gpg`|
|`ANSIBLE_GPG_AGENT`|`gpg-agent`|Command invoked for `gpg-agent`|
|`ANSIBLE_GPG_CONNECT_AGENT`|`gpg-connect-agent`|Command invoked for `gpg-connect-agent`|
|`ANSIBLE_GPG_AGENT_INFO`|`~/.gnupg/.ansible-gpg-agent-info`|Path to write environment variables|
|`ANSIBLE_GPG_LANG`|`C`|Locale setting|

The locale setting is recommended to be fixed to `C`.
`pinentry-curses` makes severely broken output in I18n environment,
and locale mismatch between `gpg` and `gpg-agent` causes fatal crashes
including segmentation faults.

## GnuPG Set up

### GnuPG Installation

First, install GnuPG v2 if it's not available in your system.
By default our scripts use `gpg2` command for GnuPG invocations.
It's GnuPG v2 executable in common Linux distributions
including Debian/RHEL and their derivatives.

Why we use GnuPG v2, not v1?  It's because only v2 supports
passphrase caching for symmetric cipher encryptions.
If you are going to use only public key encryptions, v1 might suffice,
but public key set up would be much more complicated than symmetric ones,
so I won't recommend it to everyone.

While inclined to use v2 for such reasons,
v2 suite (GnuPG v2 and other supporting software) seems still immature and
has some problems we need workaround for, unfortunately.
Especially pinentry and locale related bugs might bring terrible experiences
to users of Ansible in CLI-only environment.

Note that you can still use GnuPG v1 for encryption.
Data created by v1 is all compatible with v2 invoked by our scripts.

**Debian/Ubuntu:**
On those distribution standard `gnupg` package has v1 as `/usr/bin/gpg`,
so you need to install `gnupg2` for v2 as `/usr/bin/gpg2`.
In CLI-only environment
I recommend you to also install `pinentry-curses` at the same time
to avoid bloating with default dependecy `pinentry-gtk2`:

    $ sudo apt-get install gnupg2 pinentry-curses

On Ubuntu 15.10 or later with pinentry 0.9,
`pinentry-tty` is available and that's more recommendable option
because things seem less broken than using `pinentry-curses`:

    $ sudo apt-get install gnupg2 pinentry-tty

**RHEL/CentOS:**
On RHEL 6 or later you already have
GnuPG v2 as `/usr/bin/gpg2` and `/usr/bin/gpg` (symlinked to `gpg2`).
There's no GnuPG v1 option.

**Mac OS X:**
To be written.

### GnuPG Configuration

You need to have `~/.gnupg/` directory.
It's automatically created the first time you run GnuPG.
You can simply run `gpg -k` for that purpose:

    $ gpg -k
    gpg: directory `/home/yaegashi/.gnupg' created
    gpg: new configuration file `/home/yaegashi/.gnupg/gpg.conf' created
    gpg: WARNING: options in `/home/yaegashi/.gnupg/gpg.conf' are not yet active during this run
    gpg: keyring `/home/yaegashi/.gnupg/secring.gpg' created
    gpg: keyring `/home/yaegashi/.gnupg/pubring.gpg' created
    gpg: /home/yaegashi/.gnupg/trustdb.gpg: trustdb created

Then put the recommended configuration below in `~/.gnupg/gpg.conf`:

    use-agent
    cipher-algo aes256

And the following in `~/.gnupg/gpg-agent.conf`
(see [gpg-agent options](https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html) for details):

    disable-scdaemon
    default-cache-ttl     600
    max-cache-ttl         7200
    default-cache-ttl-ssh 1800
    max-cache-ttl-ssh     7200

After changing GnuPG configuration you should restart gpg-agent
by killing running one:

    $ /path/to/ansible-gpg-agent -k

## Demonstration

You need to be done with GnuPG set up explained above beforehand.

First, clone this repository and move into it:

```
$ git clone https://github.com/yaegashi/ansible-snippets
$ cd ansible-snippets/gnupg
```

Next, eval the output from `./ansible-gpg-agent -a`
and check aliases it made for you:

```
$ eval $(./ansible-gpg-agent -a)
$ alias
alias ansible='/home/yaegashi/ansible-snippets/gnupg/ansible-gpg-agent.sh -- ansible'
alias ansible-playbook='/home/yaegashi/ansible-snippets/gnupg/ansible-gpg-agent.sh -- ansible-playbook'
alias ansible-vault='/home/yaegashi/ansible-snippets/gnupg/ansible-gpg-agent.sh -- ansible-vault'
```

Let's run example playbook [playbook.yml](playbook.yml) on local connetion.
The playbook contains a reference to Ansible vault [vault.yml](vault.yml).
And [vaultpass](vaultpass) script is specified for `vault_password_file`
in [ansible.cfg](ansible.cfg).

vaultpass will show you a prompt
asking for a passphrase to decrypt the secure content embedded in the script.
In this demo you should type 6-letter passphrase `secret` in response to it.

```
$ ansible-playbook -c local -i localhost, playbook.yml 

PLAY ***************************************************************************

TASK [setup] *******************************************************************
ok: [localhost]

TASK [debug] *******************************************************************
ok: [localhost] => {
    "msg": "This is a message in vault.yml"
}

PLAY RECAP *********************************************************************
localhost                  : ok=2    changed=0    unreachable=0    failed=0   
```

You can edit or view the plain text content in the vault,
and you won't be asked for anything this time:

```
$ ansible-vault edit vault.yml
$ ansible-vault view vault.yml
---
message_in_vault: This is a message in vault.yml
```

Execute vaultpass script to see the actual password string
used for the vault encryption/decryption:

```
$ ./ansible-gpg-agent.sh -- ./vaultpass
tzzo2R6UJ6jV3UWxTn1NzTdkbdvYCIiQbXhCcZ4E/GK0BN69P9Gl6nb0QXMwrW8eB5KyMLagSlNtazLlIShlxGpyOreuPrBkc70MyUPbIBjxZrawYULdg9uXbdzYsYbdutQGilp9jETu8G1r6e9Fvc3vZN3/yKSQtjAiyJWvIwOVzUkRdT6Lb2tF+6Sr+A/Gzf7tDKjMOuLplRaM2jGGUL/Q8hzH+vy5jsHARgHMJzAq/NoELzWGtto96BbH/UNU
```

You can make gpg-agent drop cached credentials by `-r`,
that causes it to again ask you for the passphrase for vaultpass script:

```
$ ./ansible-gpg-agent.sh -r
$ ansible-vault edit vault.yml
```

Try SSH agent feature.  You might be asked passphrases 3 times:
1) passphrase to key file decryption by `ssh-add`,
2) new passphrase to secure your private key stored in gpg-agent,
3) the same passphrase as 2) for confirmation.

```
$ ./ansible-gpg-agent -- ssh-add /path/to/your-key.id_rsa
Enter passphrase for /path/to/your-key.id_rsa
Identity added: /path/to/your-key.id_rsa (/path/to/your-key.id_rsa)
$ ./ansible-gpg-agent -- ssh-add -l
2048 a3:99:3a:ef:b5:ad:29:39:bb:a4:dd:f1:ac:e4:b9:82 /path/to/your-key.id_rsa (RSA)
$ ansible-playbook -i your-server, playbook.yml
```

Finally, you can terminate gpg-agent by `-k`:

```
$ ./ansible-gpg-agent.sh -k
```

## Known Bugs and Limitations

Currently gpg-agent won't forget passphrases for SSH keys
by `ansible-gpg-agent.sh -r`.  The correct way to achieve it is not yet known.

## Credits

YAEGASHI Takeshi <yaegashi@debian.org>

I appreciate any corrections or suggestions on this document.
Please file issues or send pull requests at
https://github.com/yaegashi/ansible-snippets.

I'm mainly using Debian/Ubuntu server boxes,
so verification on other distros or OSes are totally missing for now.
Just a report saying "it works / doesn't work on my box"
would be a great help!
