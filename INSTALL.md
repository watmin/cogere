### Installation

`cogere` expects to be installed within the directory `/opt/sv`. The files in `bin`, `cogere` and `lib` are built with the assumed relative path of `/opt/sv`. If you install this tool into another directory you will either need to update the default directory variable within `bin/cogere` or always supply the `--config|-f` switch to load the alternate configuration.

#### Configuration

You will need to setup the configuration file `cogere/cogere.conf` for you environment. The defaults within `cogere/cogere.conf` should be sufficient for your needs. 

##### Logging

The `logstash` type is intended for use with a logstash listener on a TCP/UDP port with a filter performing JSON parsing. This logger uses SV::Logger

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
