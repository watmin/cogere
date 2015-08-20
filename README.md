# cogere

Broadcast commands to remote hosts via SSH

# Usage

```
cogere -- verb: to collect/gather, to compel/force

Usage: cogere --reason 'report hostname' --host host1 --host host2 'hostname'

Operations:
  -h|--host       Host to connect to, can be provided multiple times. Commands
                    are executed on hosts if no other operations provided.
                    Requires -r|--reason
  --add-host      Creates new host entry and keys remote host.
                    Requires --hostname, --ipaddr.
                    Optionally --username, --group|-g, --default-key
  --del-host      Removes host entry and remove key from remote host
                    Requires --hostname
  --rekey-hosts   Creates new SSH key, removes old SSH key and installs
                    new SSH key on remote host.
                    Requires -h|--host
  -g|--group      Group to connect to, can be provided multiple times. Commands
                    are executed on groups if no other operations provided.
                    Requires -r|--reason
  --add-group     Creates new group of hosts.
                    Requires -g|--group, -h|--host
  --del-group     Delete group.
                    Requires -g|--group
  --join-group    Adds hosts to an existing group.
                    Requires -g|--group, -h|--host
  --leave-group   Remove hosts from an existing group.
                    Requires -g|--group, -h|--host

Options:
  --help              Shows this output
  -f|--config         Alternate configuration file
  --hostname          Hostname to be provided to --add-host or --del-host
  --ipaddr            IP address to be provided to --add-host
  --username          User name to be provided to --add-host
                        Optional, 'cogere' is used by default
  -r|--reason         Explanation of the commands you are running
  -a|--all            Builds a group of all defined hosts.
  -F|--fork           Forks supplied number of connections and waits for them
                        to complete, the continues. The keywords 'a' or 'all'
                        will produce a fork number equal to the number of
                        hosts supplied
  -H|--list-hosts     Displays all defined hosts
  -G|--list-groups    Displays all defined groups
  -M|--list-members   Displays all hosts within group
                        Requires -g|--group
  --command-file      Execute commands provided by command-file
  -s|--scp-source     Performs an scp on local file or directory
                        Requires -t|--scp-target
  -t|--scp-target     Performs an scp to target remote directory
                        Requires -s|--scp-file
  --scp-only          Only copy files to remote hosts
  --default-key       Uses the default SSH key rather than password
                        when adding host
  --new-default       Create a new default SSH key
  --show-default      Prints the default public key
  --cleanup           Removes all entries for supplied host
                        Requires --hostname

Notes:
  Adding new hosts to existing groups:
    You can supply --group|-g to --add-host to add the new host
    to the supplied groups
  Host and group negation:
    Hosts and groups can be negated by prefixing them with ':'
  Mulitple commands:
    Multiple commands can be specified as arguments, they will
    be ran in sequence

John Shields - SmartVault Corporation - 2015
```

### Example

```
$ cogere -a -r 'report hostname' hostname
arbitrium.jar00n.net
cognitio.watministrator.net

```

### Installation

`cogere` expects to be installed within the directory `/opt/sv`. The files in `bin`, `cogere` and `lib` are built with the assumed relative path of `/opt/sv`. If you install this tool into another directory you will either need to update the default directory variable within `bin/cogere` or always supply the `--config|-f` switch to load the alternate configuration.

#### Configuration

You will need to setup the configuration file `cogere/cogere.conf` for you environment. The defaults within `cogere/cogere.conf` should be sufficient for your needs. Though you will likely need to remove the logstash entry from the log_type list.

##### Logging

The `logstash` type is intended for use with a logstash listener on a TCP/UDP port with a filter performing JSON parsing.

The `file` type simply write to the defined `log_file`.

#### sudo

`cogere` expects to be ran under `sudo` and will not run if sudo was not invoked. This is for logging purposes.

Once all three directories (`bin`, `cogere`, `lib`) are installed within the same parent directory you will need to allow your user account(s) to run the tool via sudo. By convention we use the group `admin` to run this tool.

Example sudo config:
```
Cmnd_Alias COGERE = /opt/sv/bin/cogere
%admin ALL=NOPASSWD:COGERE
```

To simplify the use of the tool I create the following alias for all users, I add it to the `/etc/profile` file:

Example alias definition:
```
alias cogere='sudo /opt/sv/bin/cogere'
```

##### bash completion

Adding `source /opt/sv/etc/bash_completion.d/cogere` to your profile will allow you to tab complete groups and hosts.

### Documentation

#### Operations

Operations perform a given operation on a set of supplied parameters from the options detailed below. If multiple operations are provided, only one will be performed.

**Don't supply multiple operations.**

###### --host | -h

The `--host` switch is both an operation and an option. When using another operation it provides the list of hosts to the operation.

If ran with no other operations, it runs the supplied command on the host. Can be supplied multiple times

**REQUIRES `--reason|-r`, `command`**

Example:
```
$ cogere --reason 'report hostname' --host arbitrium --host cognitio 'hostname'
arbitrium.jar00n.net
cognitio.watministrator.net
```

###### --group | -g

The `--group` switch is both an operation and an option. When using another operation it evaluates the group(s) to a list of hosts for the operation.

If ran with no other operations, it runs the supplied command on the group. Can be supplied multiple times

**REQUIRES `--reason|-r`, `command`**

Example:
```
$ cogere --reason 'report hostname' --group testing 'hostname'
arbitrium.jar00n.net
cognitio.watministrator.net
```

###### --add-host

Adds the supplied host to the hosts configuration. The command must be provided `--hostname` and `--ipaddr` containing the hostname and IP address of the node. Optionally takes a `--username`, the default username is cogere. You may also supply the `--default-key` switch if the remote host is already keyed. This will rekey the host and does not prompt for a password.

**REQUIRES `--hostname`, `--ipaddr`**

**OPTIONAL `--username`,`--default-key`**

Example:
```
$ cogere --add-host --hostname cognitio --ipaddr 172.16.0.6
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
WARNING : Unauthorized access to this system is forbidden and will be
prosecuted by law. By accessing this system, you agree that your actions
may be monitored if unauthorized usage is suspected.
cogere@172.16.0.6's password:
```

*I suggest that you remove the account's password once keyed.*

###### --del-host

Deletes the supplied host from the local hosts configuration, removes the SSH key from the node and deletes the local SSH keys for the node. Also removes host from any groups

**REQUIRES `--hostname`**

Example:
```
$ cogere --del-host --hostname cognitio
```

###### --add-group

Creates a new group using the supplied group name, adding members to the group from the provided host list

**REQUIRES `--group|-g`, `--host|-h`**

Example:
```
$ cogere --add-group --group moar-hosts --host arbitrium
```
###### --del-group

Deletes supplied group. Does not delete host entries.

**REQUIRES `--group|-g`**

Example:
```
$ cogere --del-group --group moar-hosts
```

###### --join-group

Adds provided hosts to provided group

**REQUIRES `--group|-g`, `--host|-h`**

Example:
```
$ cogere --join-group --group moar-hosts --host cognitio
```

###### --leave-group

Removes provided hosts to provided group

**REQUIRES `--group|-g`, `--host|-h`**

Example:
```
$ cogere --leave-group --group moar-hosts --host arbitrium
```

##### Options

Options are optional parameters unless other noted for given operation.

###### --config | -f

Allows for loading of a different configuration file. You likely won't ever use this.

###### --hostname

Provides hostname variable to `--add-host` or `--del-host`

###### --ipaddr

Provides IP address variable to `--add-host` or `--del-host`

###### --reason | -r

Provides a reason as to why you are doing what you are doing on the host(s) or group(s)

###### --all | -a

Builds a host list of all defined hosts.

###### --fork | -F

The `--fork|-F` option allows the script to process connections in parallel. This option takes either an integer for max number of concurrent connections or the keywords `a` or `all` to produce an integer for all hosts supplied.

When forking is used, all lines are prefixed with the hostname the line came from.

Example:
```
$ cogere -r 'forking' -a -F a \
  'for i in {0..5}; do sleep $(( $RANDOM % 3 )); echo $i; done'
[arbitrium] 0
[cognitio] 0
[cognitio] 1
[cognitio] 2
[arbitrium] 1
[cognitio] 3
[arbitrium] 2
[cognitio] 4
[cognitio] 5
[arbitrium] 3
[arbitrium] 4
[arbitrium] 5
```

###### --scp-source | -s , --scp-target | -t, --scp-only

Performs an scp on source file or directory to target directory on remote host. If `--scp-only` is used no command will be executed and can be witheld entirely

**REQUIRES `--scp-source|-s`, `--scp-target|-t`**

**OPTIONALLY `--scp-only`**

Example:
```
$ cat << EOF > /tmp/bash-me
head -n2 /etc/hosts
EOF
$ cogere -r 'scp testing' -a --scp-source /tmp/bash-me --scp-target /tmp \
  'hostname; bash /tmp/bash-me; rm -f /tmp/bash-me; echo'
arbitrium.jar00n.net
127.0.0.1	localhost
127.0.1.1	arbitrium.jar00n.net	arbitrium

cognitio.watministrator.net
127.0.0.1	localhost
127.0.1.1	cognitio.watministrator.net cognitio

```
*`--scp-target` must be a directory*

###### --new-default

Creates a new default key, overwriting a previous one if it exists

Example:

```
$ cogere --new-default
```

###### --show-default

Prints the default public key

Example:

```
$ cogere --show-default
ssh-rsa [shortened-key] [remote-id]
```

###### --default-key

Uses the default SSH key when adding a host, requires the that public key is already on the remote host. Intended for use with Puppet, Chef, Salt, etc.

Example:

```
$ cogere --add-host --hostname cognitio --ipaddr 172.16.0.6 --default-key
```

###### --cleanup

Removes any host entries and keys on the local system for the provided hostname

**REQUIRES `--hostname`**

###### --command-file

Builds a commands array from file. Commands are executed in the order they are written.

Example:

```
$ cat << EOF > commands.txt
> hostname
> hostname
> EOF
$ cogere -r debug -h cognitio --command-file commands.txt
cognitio.watministrator.net
cognitio.watministrator.net
```

###### --list-hosts | -H

Lists all defined hosts.

Example:
```
$ cogere --list-hosts
arbitrium
cognitio
```

###### --list-groups | -G

Lists all defined groups and their members.

Example:
```
$ cogere --list-groups
moar-hosts - cognitio
testing - arbitrium
```

###### --list-members | -M

Lists members of supplied group

**REQUIRES `--group|-g`**

Example:
```
$ cogere --list-members --group testing
testing - arbitrium
```

##### Notes

These are various examples and use cases demonstrating the tool's functionality.

###### Heredocs

You can supply heredocs as the command if they properly shell escaped.

Example:
```
$ cogere -r 'heredoc demo' -a 'perl <<'\''EOF'\'
use strict;
use warnings;

use Sys::Hostname;

print "Hi! My name is ${\hostname}\n";

exit;
EOF
echo My username is $(whoami)
echo
'
Hi! My name is arbitrium.jar00n.net
My username is cogere

Hi! My name is cognitio.watministrator.net
My username is cogere

```

**Remember: To escape a single quote use the following sequence `'\''`**

###### Forking

It is important to note that output lines are only sent back when the remote side flushes their buffers. So, if you cat a file it will be printed intact on the cogere side.

Example:
```
$ cogere -r 'stdout forking' -a -F a 'head -n3 /etc/hosts'
[arbitrium] 127.0.0.1	localhost
[arbitrium] 127.0.1.1	arbitrium.jar00n.net	arbitrium
[arbitrium] 
[cognitio] 127.0.0.1	localhost
[cognitio] 127.0.1.1	cognitio.watministrator.net cognitio
[cognitio] 
```

However, if the output is flushed on each line, then the output will be printed one line at a time causing the output on cogere to be intermixed with lines from the hosts being connected to.

Example:
```
$ cogere -r 'stdout forking' -a -F a \
  'while read line; do echo "$line"; sleep 1; done < <(head -n3 /etc/hosts)'
[arbitrium] 127.0.0.1	localhost
[cognitio] 127.0.0.1	localhost
[arbitrium] 127.0.1.1	arbitrium.jar00n.net	arbitrium
[cognitio] 127.0.1.1	cognitio.watministrator.net cognitio
[arbitrium] 
[cognitio] 
```

Here I used `sleep` to break up the command output to ensure the lines were sent one at a time, depending on the speed of the operation all lines could be sent in tact like the previous example.

###### Host and Group negation

Hosts and groups can be negated from the target hosts by prefixing them with `:`.

Example:
```
$ cogere -G
group1 - cognitio
group2 - arbitrium,cognitio
$ cogere -r 'negation demo' -a -g :group1 hostname
arbitrium.jar00n.net 
```

###### Multiple commands

Mulitple commands can be supplied as arguments.

Example:

```
$ cogere -r 'multiple commands' -h cognitio hostname hostname
cognitio.watministrator.net
cognitio.watministrator.net
```

Here I have two commands supplied, hostname twice.

Here I supplied `-a` to build a list of all known hosts and then used `-g :group1` to remove the hosts within group1 from the hosts list.

### To do's
- Optionally use DNS if `--ipaddr` not provided with `--add-host`
