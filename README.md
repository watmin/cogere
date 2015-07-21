# cogere
Broadcast commands to remote hosts via SSH

# Usage
```
./cogere.pl -h
  cogere -- verb: to collect/gather, to compel/force

  Usage: cogere --comment 'report hostname' --host-list hostname1,hostname2 'hostname'

  Operations:
    --host-list    Comma separated hostname list, command is executed on hosts
                     if no other operations provided. Requires --comment
    --rekey-hosts  Creates new SSH key, removes old SSH key and installs
                     new SSH key on remote host. Requires --host-list
    --add-host     Creates new host entry and keys remote host.
                     Requires --hostname, --ipaddr. Optionally --username
    --del-host     Removes host entry and remove key from remote host

  Options:
    -h|--help      Shows this output
    --hostname     Hostname to be provided to --add-host or --del-host
    --ipaddr       IP address to be provided to --add-host
    --username     User name to be provided to --add-host
                     Optional, 'cogere' is used by default
    --comment      Explanation of the command you are running

  John Shields - SmartVault Corporation - 2015
```
### Example
```
./cogere.pl --comment 'testing' --host-list arbitrium,cognitio 'hostname; ip addr | perl -ne "print if /tun\d+:/../inet/"; echo'
LOGGER process_host_list
$VAR1 = {
          'application' => 'cogere',
          'command' => 'hostname; ip addr | perl -ne "print if /tun\\d+:/../inet/"; echo',
          'hosts' => [
                       'arbitrium',
                       'cognitio'
                     ],
          'message' => 'testing',
          'user' => 'jshields'
        };
arbitrium.jar00n.net
4: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 100
    link/none 
    inet 172.16.0.1 peer 172.16.0.2/32 scope global tun0

cognitio.watministrator.net
3: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN qlen 100
    link/none 
    inet 172.16.0.6 peer 172.16.0.5/32 scope global tun0
```
