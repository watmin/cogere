# cogere
Broadcast commands to remote hosts via SSH

# Usage
```
cogere -- verb: to collect/gather, to compel/force

Usage: cogere --reason 'report hostname' --host-list host1,host2 'hostname'

Operations:
  -l|--host-list  Comma separated hostname list, command is executed on hosts
                    if no other operations provided.
                    Requires --reason
  --add-host      Creates new host entry and keys remote host.
                    Requires --hostname, --ipaddr. Optionally --username
  --del-host      Removes host entry and remove key from remote host
                    Requires --hostname
  --rekey-hosts   Creates new SSH key, removes old SSH key and installs
                    new SSH key on remote host.
                    Requires --host-list
  -g|--group      Comma separated group list, command is executed on groups
                    if no other operations provided.
                    Requires --reason
  --add-group     Creates new group of hosts.
                    Requires --group, --host-list
  --del-group     Delete group.
                    Requires --group
  --join-group    Adds hosts to an existing group.
                    Requires --group, --host-list
  --leave-group   Remove hosts from an existing group.
                    Requires --group, --host-list

Options:
  -h|--help           Shows this output
  -f|--config         Alternate configuration file
  --hostname          Hostname to be provided to --add-host or --del-host
  --ipaddr            IP address to be provided to --add-host
  --username          User name to be provided to --add-host
                        Optional, 'cogere' is used by default
  -r|--reason         Explanation of the command you are running
  -a|--all            Builds a group of all defined hosts.
  -F|--fork           Forks supplied number of connections and waits for them
                        to complete, the continues. The keywords 'a' or 'all'
                        will produce a fork number equal to the number of
                        hosts supplied
  -H|--list-hosts     Displays all defined hosts
  -G|--list-groups    Displays all defined groups
  -M|--list-members   Displays all hosts within group
                        Requires --group

John Shields - SmartVault Corporation - 2015
```
### Example
```
cogere -a -r 'report hostname' hostname
arbitrium.jar00n.net
cognitio.watministrator.net

```
### Installation

### Documentation

#### Operations

Operations perform a given operation on a set of supplied parameters from the options detailed below. If multiple operations are provided, only one will be performed.

**Don't supply multiple operations.**

###### --host-list | -l

The --host-list switch is both an operation and an option. When using another operation it provides the list of hosts to the operation.

If ran with no other operations, it runs the supplied command on the host. Can supply multiple hosts comma separated

**REQUIRES `--reason|-r, command`**

### To do's
- Allow for hostname negation
- Replace comma separated hosts/groups with multiple -l/g switches (Allows for tab completion)
- Allow for host removal of unreachable hosts
- Allow for use of preexisting key in --add-host (Allows for automated deploy hosts to be already keyed, will rekey on add)
- Allow for hosts to added to groups on creation
- Optionally use DNS if --ipaddr not provided with --add-host
