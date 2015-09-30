package Cogere;

use strict;
use warnings;

use Cogere::HostsManager;
use Cogere::Util;
use Cogere::HostsConfig;
use Cogere::Config;
use Cogere::Commands;

use Net::OpenSSH;
use Parallel::ForkManager;

use Hash::Util::FieldHash qw/fieldhash/;
use Carp;

our $VERSION = 0.1;

fieldhash my %_config;
fieldhash my %_fork;
fieldhash my %_commands;
fieldhash my %_commands_file;
fieldhash my %_hosts;
fieldhash my %_groups;
fieldhash my %_hosts_config;
fieldhash my %_hosts_manager;
fieldhash my %_util;
fieldhash my %_user;
fieldhash my %_reason;
fieldhash my %_scp_mkdir;
fieldhash my %_scp_source;
fieldhash my %_scp_target;
fieldhash my %_scp_only;
fieldhash my %_stop_on_fail;
fieldhash my %_use_default_key;
fieldhash my %_backup;
fieldhash my %_all_hosts;

sub new {
    my ( $class, %args ) = @_;

    defined $args{'user'} or croak "Failed to provide user to Cogere.";

    my ( $self, $object );
    $self = bless \$object, $class;

    $self->user( $args{'user'} );
    delete $args{'user'};

    my $config = Cogere::Config->new(%args);
    $self->config($config);

    my %hosts_config_args = (
        'hosts-config'  => $self->config->hosts_conf_path,
        'cogere-config' => $self->config,
    );
    my $hosts_config = Cogere::HostsConfig->new(%hosts_config_args);
    $self->hosts_config($hosts_config);

    my %hosts_manager_args = (
        'hosts-config' => $self->hosts_config,
        'default_key'  => $self->config->default_key,
    );
    my $hosts_manager = Cogere::HostsManager->new(%hosts_manager_args);
    $self->hosts_manager($hosts_manager);

    my %util_args = (
        'cogere-config' => $self->config,
    );
    my $util = Cogere::Util->new(%util_args);
    $self->util($util);

    return $self;
}

sub list_hosts {
    my ($self) = @_;

    $self->hosts_manager->list_hosts;

    return;
}

sub list_groups {
    my ($self) = @_;

    $self->hosts_manager->list_groups;

    return;
}

sub list_members {
    my ( $self, $group ) = @_;

    defined $group or croak "Failed to provide group.";

    $self->hosts_manager->list_members($group);

    return;
}

sub print_default_key {
    my ($self) = @_;

    $self->util->print_default_key;

    return;
}

sub new_default_key {
    my ($self) = @_;

    my ( $password, $remoteid ) = $self->util->new_default_key( $self->config->default_key );
    $self->hosts_config->new_host(
        'hostname' => $self->config->default_key,
        'password' => $password,
        'remoteid' => $remoteid,
    );
    $self->util->print_default_key;

    return;
}

sub key_from_default {
    my ( $self, $hostname ) = @_;

    $self->stop_on_fail(1);

    my $host = $self->hosts_config->get_host($hostname);
    $host    = $self->util->add_defaults( $hostname, $host );

    $self->util->copy_default_key($hostname);
    $self->_backup( $self->util->backup_key($hostname) );
    my ( $password, $remoteid ) = $self->util->gen_key($hostname);

    my %command_add = Cogere::Commands::add_remote_key(
        'hostname'   => $hostname,
        'host'       => $host,
        'public-key' => $host->{'public-key'},
    );
    $self->_parse_command_set(%command_add);

    my $failed_new = $self->connect;
    if ($failed_new) {
        carp "Failed to add new key to '$hostname'.";
        $self->cleanup_host($hostname);
        return 1;
    }

    $self->hosts_config->del_host(
        'hostname' => $hostname,
    );
    $self->util->del_key(
        'hostname' => $hostname,
        'backup'   => $self->_backup,
    );

    $self->hosts_config->new_host(
        'hostname' => $hostname,
        'remoteid' => $remoteid,
        'password' => $password,
        'username' => $host->{'username'},
        'ipaddr'   => $host->{'ipaddr'},
        'port'     => $host->{'port'},
    );

    my %command_del = Cogere::Commands::del_remote_key(
        'hostname' => $hostname,
        'host'     => $host,
        'remoteid' => $host->{'remoteid'},
    );
    $self->_parse_command_set(%command_del);

    $self->_backup(0);

    my $failed_del = $self->connect;
    if ($failed_del) {
        carp "Failed to remove default key from '$hostname'.";
        return 1;
    }

    return;
}

sub new_host {
    my ( $self, %args ) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname.";
    $self->hosts_config->get_host( $args{'hostname'} )
      and croak "Hostname '$args{'hostname'} already defined.";

    if ( defined $args{'groups'} ) {
        $self->hosts_config->validate_groups( @{ $args{'groups'} } );
    }

    if ( !$self->use_default_key ) {
        ( $args{'password'}, $args{'remoteid'} ) = $self->util->gen_key( $args{'hostname'} );
        my $failure = $self->_copy_key(%args);

        if ( $failure ) {
            carp "Failed to copy key to '$args{'hostname'}'.";
            $self->cleanup_host($args{'hostname'});
            return 1;
        }

        $self->hosts_config->new_host(%args);
    }
    else {
        my $def = $self->hosts_config->get_host( $self->config->default_key );
        $args{'password'} = $def->{'password'};
        $args{'remoteid'} = $def->{'remoteid'};
        $self->hosts_config->new_host(%args);
        
        my $failure = $self->key_from_default( $args{'hostname'} );

        if ( $failure ) {
            carp "Failed to key '$args{'hostname'}' using default key.";
            $self->cleanup_host($args{'hostname'});
            return 1;
        }
    }

    print "Successfully added '$args{'hostname'}'.\n";

    if ( $args{'groups'} ) {
        $self->hosts_config->join_group(
            'hosts'  => [ $args{'hostname'} ],
            'groups' => $args{'groups'},
        );
    }

    return;
}

sub del_host {
    my ( $self, $hostname ) = @_;

    defined $hostname or croak "Failed to provide hostname.";

    my $host = $self->hosts_config->get_host($hostname);
    $host = $self->util->add_defaults( $hostname, $host );

    my %command_set = Cogere::Commands::del_remote_key(
        'hostname' => $hostname,
        'host'     => $host,
    );
    $self->commands( @{ $command_set{'commands'} } );
    $self->hosts( 'hosts' => $command_set{'hosts'} );
    $self->reason( $command_set{'reason'} );

    my $failure = $self->connect;
    
    if ( $failure ) {
        carp "Failed to delete remote key '$hostname'.";
        $self->cleanup_host($hostname);
        return 1;
    }

    $self->hosts_config->del_host( 'hostname' => $hostname );
    $self->util->del_key( 'hostname' => $hostname );

    print "Sucessfully deleted '$hostname'.\n";

    return;
}

sub cleanup_host {
    my ( $self, $hostname ) = @_;

    defined $hostname or croak "Failed to provide hostname.";

    my $host = $self->hosts_config->get_host($hostname);

    if ($host) {
        $self->hosts_config->del_host( 'hostname' => $hostname );
    }

    $self->util->del_key( 'hostname' => $hostname );

    return;
}

sub update {
    my ( $self, %args ) = @_;

    $self->hosts_config->update(%args);

    return;
}

sub remove_fingerprint {
    my ( $self, $hostname ) = @_;

    my $host = $self->hosts_config->get_host($hostname);
    $self->util->remove_fingerprint( $hostname, $host );

    return;
}

sub new_group {
    my ( $self, %args ) = @_;

    $self->hosts_config->new_group(%args);

    return;
}

sub del_group {
    my ( $self, %args ) = @_;

    $self->hosts_config->del_group(%args);

    return;
}

sub join_group {
    my ( $self, %args ) = @_;

    $self->hosts_config->join_group(%args);

    return;
}

sub leave_group {
    my ( $self, %args ) = @_;

    $self->hosts_config->leave_group(%args);

    return;
}

sub commands {
    my ( $self, @commands ) = @_;

    if (@commands) {
        $_commands{$self} = [ @commands ];
    }

    return $_commands{$self};
}

sub commands_file {
    my ( $self, $commands_file ) = @_;

    if ( !defined $_commands_file{$self} and defined $commands_file ) {
        if ( !-f $commands_file ) {
            croak "Commands file not found.";
        }
        else {
            $_commands_file{$self} = $commands_file;
            open my $command_h, '<', $self->commands_file
              or croak "Failed to open commands file '${\$self->commands_file}: $!";

            my ( $command, @read_commands );
            while ( $command = <$command_h> ) {
                chomp $command;
                push @read_commands, $command;
            }

            close $command_h;

            $self->commands(@read_commands);
        }
    }

    return $_commands_file{$self};
}

sub all_hosts {
    my ( $self, $all_hosts ) = @_;

    if ( defined $all_hosts ) {
        $_all_hosts{$self} = $all_hosts;
    }

    return $_all_hosts{$self};
}

sub hosts {
    my ( $self, @hosts ) = @_;

    if (@hosts) {
        $_hosts{$self} = [ @hosts ];
    }

    return $_hosts{$self};
}

sub groups {
    my ( $self, @groups ) = @_;

    if (@groups) {
        $_groups{$self} = [ @groups ];
    }

    return $_groups{$self};
}

sub targets {
    my ($self) = @_;

    my %targets = (
        'hosts'  => $self->hosts,
        'groups' => $self->groups,
        'all'    => $self->all_hosts,
    );

    my @target_hosts = $self->hosts_manager->get_hosts(%targets);

    return [ @target_hosts ];
}

sub reason {
    my ( $self, $reason ) = @_;

    if ( defined $reason ) {
        $_reason{$self} = $reason;
    }

    return $_reason{$self};
}

sub fork {
    my ( $self, $fork ) = @_;

    if ( defined $fork ) {
        if ( $fork =~ /^(a|all)$/i ) {
            my @hosts = $self->hosts_config->get_all_hosts;
            $_fork{$self} = $#hosts + 1;
        }
        elsif ( $fork !~ /^\d+$/ ) {
            croak "Fork argument '$fork' is invalid.";
        }
        else {
            $_fork{$self} = $fork;
        }
    }

    return $_fork{$self};
}

sub scp_source {
    my ( $self, $scp_source ) = @_;

    if ( !defined $_scp_source{$self} and defined $scp_source ) {
        $_scp_source{$self} = $scp_source;
    }
    elsif ( defined $_scp_source{$self} and defined $scp_source ) {
        carp "Cogere scp source already defined.";
    }

    return $_scp_source{$self};
}

sub scp_target {
    my ( $self, $scp_target ) = @_;

    if ( !defined $_scp_target{$self} and defined $scp_target ) {
        $_scp_target{$self} = $scp_target;
    }
    elsif ( defined $_scp_target{$self} and defined $scp_target ) {
        carp "Cogere scp target already defined.";
    }

    return $_scp_target{$self};
}

sub scp_mkdir {
    my ( $self, $scp_mkdir ) = @_;

    if ( !defined $_scp_mkdir{$self} and defined $scp_mkdir ) {
        $_scp_mkdir{$self} = $scp_mkdir;
    }
    elsif ( defined $_scp_mkdir{$self} and defined $scp_mkdir ) {
        carp "Cogere scp mkdir already defined.";
    }

    return $_scp_mkdir{$self};
}

sub scp_only {
    my ( $self, $scp_only ) = @_;

    if ( !defined $_scp_only{$self} and defined $scp_only ) {
        $_scp_only{$self} = $scp_only;
    }
    elsif ( defined $_scp_only{$self} and defined $scp_only ) {
        carp "Cogere scp only already defined.";
    }

    return $_scp_only{$self};
}

sub connect {
    my ($self) = @_;

    defined $self->targets  or croak "No hosts defined.";
    defined $self->commands or croak "No commands defined.";
    defined $self->reason   or croak "No reason defined.";

    my %log = (
        'user'     => $self->user,
        'hosts'    => [ $self->targets ],
        'commands' => $self->commands,
        'reason'   => $self->reason,
    );
    $self->util->write_log(%log);

    my $failure = $self->_run_commands;

    if ( $failure and $self->stop_on_fail ) {
        return 1;
    }

    return;
}

sub rekey_hosts {
    my ($self) = @_;

    $self->hosts or croak "No hosts provided.";

    my $failed;

    for my $hostname ( @{ $self->targets } ) {
        my $host = $self->hosts_config->get_host($hostname);

        $self->_backup( $self->util->backup_key($hostname) );
        my ( $password, $remoteid ) = $self->util->gen_key($hostname);

        my %command_add = Cogere::Commands::add_remote_key(
            'hostname'   => $hostname,
            'host'       => $host,
            'public-key' => $host->{'public-key'},
        );
        $self->_parse_command_set(%command_add);

        my $failed_add = $self->connect;
        if ($failed_add) {
            $failed = 1;
            carp "Failed to add new key to '$hostname'.";
            next;
        }

        $self->hosts_config->del_host(
            'hostname'        => $hostname,
            'preserve-groups' => 1,
        );
        $self->util->del_key(
            'hostname' => $hostname,
            'backup'   => $self->_backup,
        );

        $self->hosts_config->new_host(
            'hostname' => $hostname,
            'remoteid' => $remoteid,
            'password' => $password,
            'username' => $host->{'username'},
            'ipaddr'   => $host->{'ipaddr'},
            'port'     => $host->{'port'},
        );

        my %command_del = Cogere::Commands::del_remote_key(
            'hostname' => $hostname,
            'host'     => $host,
            'remoteid' => $host->{'remoteid'},
        );
        $self->_parse_command_set(%command_del);

        $self->_backup(0);

        my $failed_del = $self->connect;
        if ($failed_del) {
            $failed = 1;
            carp "Failed to remove old key from '$hostname'.";
            next;
        }
    }

    return $failed;
}

sub stop_on_fail {
    my ( $self, $stop ) = @_;

    if ( !defined $_stop_on_fail{$self} and defined $stop ) {
        $_stop_on_fail{$self} = $stop;
    }

    return $_stop_on_fail{$self};
}

sub use_default_key {
    my ( $self, $use_default_key ) = @_;

    if ( !defined $_use_default_key{$self} and defined $use_default_key ) {
        $_use_default_key{$self} = $use_default_key;
    }
    elsif ( defined $_use_default_key{$self} and defined $use_default_key ) {
        carp "Cogere use_default_key already defined.";
    }

    return $_use_default_key{$self};
}

sub user {
    my ( $self, $user ) = @_;

    if ( !defined $_user{$self} and defined $user ) {
        $_user{$self} = $user;
    }
    elsif ( defined $user and defined $user ) {
        carp "Cogere user already defined.";
    }

    return $_user{$self};
}

sub config {
    my ( $self, $config ) = @_;

    if ( !defined $_config{$self} and defined $config ) {
        $_config{$self} = $config;
    }
    elsif ( defined $_config{$self} and defined $config ) {
        carp "Cogere::Config already created.";
    }

    return $_config{$self};
}

sub hosts_config {
    my ( $self, $hosts_config ) = @_;

    if ( !defined $_hosts_config{$self} and $hosts_config ) {
        $_hosts_config{$self} = $hosts_config;
    }
    elsif ( defined $_hosts_config{$self} and defined $hosts_config ) {
        carp "Cogere's Cogere::HostsConfig already defined.";
    }

    return $_hosts_config{$self};
}

sub hosts_manager {
    my ( $self, $hosts_manager ) = @_;

    if ( !defined $_hosts_manager{$self} and defined $hosts_manager ) { 
        $_hosts_manager{$self} = $hosts_manager;
    }   
    elsif ( defined $_hosts_manager{$self} and defined $hosts_manager ) { 
        carp "Cogere's Cogere::HostsManager already defined.";
    }   

    return $_hosts_manager{$self};
}

sub util {
    my ( $self, $util ) = @_;

    if ( !defined $_util{$self} and defined $util ) {
        $_util{$self} = $util;
    }
    elsif ( defined $_util{$self} and defined $util ) {
        carp "Cogere's Cogere::Util already defined.";
    }

    return $_util{$self};
}

sub _copy_key {
    my ( $self, %args ) = @_;

    defined $args{'hostname'} or croak "Failed to provide hostname.";

    my $cmd = $self->config->ssh_copy_id;

    my $hostname = $args{'hostname'};
    my $port     = $args{'port'}     || $self->config->default_port;
    my $username = $args{'username'} || $self->config->default_user;
    my $ipaddr   = $args{'ipaddr'}   || $self->util->resolve_hostname($hostname);

    my $keys_path = $self->config->keys_path;
    my $key = "$keys_path/$hostname";

    my %log = (
        'user'     => $self->user,
        'reason'   => "Adding host '$hostname'",
        'hosts'    => [ $args{'hostname'} ],
        'commands' => [ "[local] $cmd -i \"$key\" -p $port $username\@$ipaddr" ],
    );
    $self->util->write_log(%log);

    my $out = `$cmd -i "$key" -p "$port" "$username\@$ipaddr"`;
    if ( $? != 0 ) {
        carp "Failed to copy SSH key to remote host '$username\@$ipaddr': $out.";
        return 1;
    }

    return;
}

sub _open_ssh {
    my ( $self, $hostname, $host ) = @_;

    defined $host or croak "Failed to provide host.";

    open my $in_garb,  '<', '/dev/null';
    open my $out_garb, '>', '/dev/null';
    open my $err_garb, '>', '/dev/null';

    my $ipaddr = $host->{'ipaddr'};

    my $ssh = Net::OpenSSH->new(
        $host->{'ipaddr'},
        'user'              => $host->{'username'},
        'port'              => $host->{'port'},
        'passphrase'        => $host->{'password'},
        'key_path'          => $host->{'private-key'},
        'default_stdout_fh' => $out_garb,
        'default_stderr_fh' => $err_garb,
        'default_stdin_fh'  => $in_garb,
        'ssh_cmd'           => $self->config->ssh,
        'scp_cmd'           => $self->config->scp,
        'master_opts'       => [
            -o => 'StrictHostKeyChecking=no',
            -o => 'CheckHostIP=no',
            -o => 'GSSAPIAuthentication=no',
            -o => 'IdentitiesOnly=yes',
            -o => 'PasswordAuthentication=no',
            -o => 'PubkeyAuthentication=yes',
        ],
    );

    if ( $ssh->error ) {
        carp "Failed to SSH to '$hostname': ${\$ssh->error}.";
        return 1;
    }

    return $ssh;
}

sub _execute_command {
    my ( $self, %args ) = @_;

    defined $args{'ssh'}      or croak "Failed to provide ssh object.";
    defined $args{'command'}  or croak "Failed to provide command.";
    defined $args{'hostname'} or croak "Failed to provide command.";

    my $ssh = $args{'ssh'};

    my ( $out, $pid ) = $ssh->pipe_out( $args{'command'} );

    if ( $ssh->error ) {
        warn "Failed to open command pipe on '$args{'hostname'}': ${\$ssh->error}.";
        return 1;
    }

    my $line;
    while ( $line = <$out> ) {
        if ( $self->fork ) {
            $line = "[$args{'hostname'}] $line";
        }
        print $line;
    }
    close $out;

    return;
}

sub _scp_put {
    my ( $self, %args ) = @_;

    defined $args{'ssh'}      or croak "Failed to provide ssh object.";
    defined $args{'hostname'} or croak "Failed to provide hostname.";

    if ( !-d $self->scp_source and !-f $self->scp_source ) {
        warn "Cannot scp '${\$self->scp_source}', source is neither a file nor a directory.";
        return 1;
    }

    my $ssh = $args{'ssh'};

    if ( $self->scp_mkdir ) {
        $self->_execute_command(
            'ssh'      => $ssh,
            'command'  => "mkdir -pv ${\$self->scp_target}",
            'hostname' => $args{'hostname'},
        );
    }

    $ssh->scp_put( { 'recursive' => 1 }, $self->scp_source, $self->scp_target );

    if ( $ssh->error ) {
        carp "Failed to scp source '${\$self->scp_source}': ${\$ssh->error}.";
        return 1;
    }

    return;
}

sub _run_commands {
    my ($self) = @_;

    my $failed;

    my $fork_num = $self->fork || 1;
    my $pm = Parallel::ForkManager->new($fork_num);

    $pm->run_on_finish(
        sub {
            my ( $pid, $exit_code, $ident ) = @_;

            if ( $exit_code == 1 ) {
                $failed = 1;
            }

            return;
        }
    );

  HOSTS:
    for my $hostname ( @{ $self->targets } ) {
        $pm->start($hostname) and next HOSTS;

        my $failure = $self->_connect_to_host($hostname);
        
        $pm->finish($failure);
    }
    $pm->wait_all_children;

    return $failed;
}

sub _connect_to_host {
    my ( $self, $hostname ) = @_;

    my $host = $self->hosts_config->get_host($hostname);
    $host = $self->util->add_defaults( $hostname, $host );
    my $source = $self->scp_source;
    my $target = $self->scp_target;

    if ( $hostname ne $self->config->default_key ) {
        $self->util->verify_host_key( $hostname, $host ) and return 1;
    }

    if ( $self->_backup ) {
        $host->{'private-key'} = "${\$self->config->keys_path}/$hostname.${\$self->_backup}";
        $host->{'public-key'}  = "${\$self->config->keys_path}/$hostname.${\$self->_backup}.pub";
    }

    my $ssh = $self->_open_ssh( $hostname, $host );
    return 1 if $ssh == 1;

    if ( $source and $target ) {
        my $failure = $self->_scp_put(
            'hostname' => $hostname,
            'ssh'      => $ssh,
        );

        if ( $failure ) {
            carp "Failed to copy source to '$hostname'.";
            return 1;
        }

        if ( $self->scp_only ) {
            print "Successfully copied '$source' to '$target' on '$hostname'.\n";
            return;
        }
    }

    for my $command ( @{ $self->commands } ) {
        my $failure = $self->_execute_command(
            'ssh'      => $ssh,
            'command'  => $command,
            'hostname' => $hostname,
        );

        if ( $failure ) {
            carp "Failed to execute command on '$hostname'.";
            return 1;
        }
    }

    return;
}

sub _parse_command_set {
    my ( $self, %command_set ) = @_;

    defined $command_set{'commands'} or croak "Failed to provide commands.";
    defined $command_set{'hosts'}    or croak "Failed to provide hosts.";
    defined $command_set{'reason'}   or croak "Failed to provide reason.";

    $self->commands( @{ $command_set{'commands'} } );
    $self->hosts( @{ $command_set{'hosts'} } );
    $self->group( @{ $command_set{'groups'} } );
    $self->all_hosts( $command_set{'all_hosts'} );
    $self->reason( $command_set{'reason'} );

    return;
}

sub _backup {
    my ( $self, $backup ) = @_;

    if ( defined $backup ) {
        $_backup{$self} = $backup;
    }

    return $_backup{$self};
}

1;

