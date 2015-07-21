#!/usr/bin/perl
use Modern::Perl;
use Getopt::Long qw/:config no_ignore_case/;
use Net::OpenSSH;
use JSON;

use lib '/home/jshields/dev/opt/sv/lib';
use SV::Logger;
my $logger = SV::Logger->new;
my ($login,$pass,$uid,$gid) = getpwuid($<);
my %log = (
    'application' => 'cogere',
    'user'        => $login,
);
my $json_o = JSON->new->utf8;

open my $in_garb, '<', '/dev/null';
open my $out_garb, '>', '/dev/null';
open my $err_garb, '>', '/dev/null';

my $base_dir   = '/home/jshields/dev/opt/sv/cogere';
my $hosts_conf = "$base_dir/hosts.conf";
my $keys_dir   = "$base_dir/keys";
my $genpass    = '/home/jshields/bin/genpass';
my $keygen     = '/usr/bin/ssh-keygen';
my $copyid     = '/usr/bin/ssh-copy-id';
my $def_user   = 'cogere';

if (!@ARGV) {
    help();
    exit;
}

my %args;
GetOptions(
    'h|help'      => \$args{'help'},
    'host-list=s' => \$args{'host-list'},
    'comment=s'   => \$args{'comment'},
    'rekey-hosts' => \$args{'rekey-hosts'},
    'add-host'    => \$args{'add-host'},
    'del-host'    => \$args{'del-host'},
    'hostname=s'  => \$args{'hostname'},
    'ipaddr=s'    => \$args{'ipaddr'},
    'username=s'  => \$args{'username'},
) or die "Invalid arguments. See $0 -h\n";

my $command = $ARGV[0];

if ($args{'help'}) {
    help();
    exit;
}
elsif ($args{'del-host'}) {
    process_del_host($args{'hostname'});
    exit;
}
elsif ($args{'add-host'}) {
    process_add_host($args{'hostname'}, $args{'ipaddr'}, $args{'username'});
    exit;
}
elsif ($args{'rekey-hosts'}) {
    process_rekey_host($args{'host-list'});
    exit;
}
elsif ($args{'host-list'}) {
    process_host_list($args{'host-list'});
    exit;
}
else {
    die "No operations provided. See $0 -h\n";
}

sub help {
    print <<EOH;
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
EOH
}

sub process_host_list {
    my ($host_list, $timestamp) = @_;

    if (!$command) {
        die "Command was not provided.";
    }

    if (!$args{'comment'}) {
        die "Comment was not provided.";
    }

    my @hosts = split /,/, $host_list;
    $log{'hosts'} = \@hosts;
    $log{'command'} = $command;
    $log{'message'} = $args{'comment'};

    for my $host (@hosts) {
        if (!get_host_line($host)){
            die "Invalid host '$host'\n";
        }
    }

    print "LOGGER process_host_list\n";
    use Data::Dumper; print Data::Dumper::Dumper(\%log);

    for my $hostname (@hosts) {
        my %params = get_params($hostname);
        if ($timestamp) {
            $params{'private'} = "$keys_dir/$hostname.$timestamp";
            $params{'public'}  = "$params{'private'}.pub";
        }
        my $ssh = Net::OpenSSH->new($params{'ipaddr'},
            'user'       => $params{'username'},
            'passphrase' => $params{'password'},
            'key_path'   => $params{'private'},
            'default_stdout_fh' => $out_garb,
            'default_stderr_fh' => $err_garb,
            'default_stdin_fh'  => $in_garb,
        );
        $ssh->error and die "Failed to establish SSH connect: ${\$ssh->error}\n";
        my ($out, $pid) = $ssh->pipe_out($command)
          or die "Failed to open command pipe ${\$ssh->error}\n";
        print while <$out>;
        close $out;
    }

    return;
}

sub process_add_host {
    my ($hostname, $ipaddr, $username) = @_;

    $hostname or die "Failed to provide hostname\n";
    $ipaddr   or die "Failed to provide IP address\n";
    $username = defined $username ? $username : $def_user;

    get_host_line($hostname) and die "Hostname '$hostname' already defined\n";

    $log{'message'} = "Adding host '$hostname'";

    my ($password, $remoteid) = gen_key($hostname);
    copy_key($hostname, $username, $ipaddr);

    add_hosts_conf($hostname, $username, $ipaddr, $password, $remoteid);

    return;
}

sub process_del_host {
    my ($hostname) = @_;

    get_host_line($hostname) or die "Hostname '$hostname' not defined\n";

    $log{'message'} = "Deleting host '$hostname'";
    print "LOGGER - proccess_del_host\n";
    use Data::Dumper; print Data::Dumper::Dumper(\%log);

    my %params = get_params($hostname);

    del_remote_key($hostname);
    process_host_list($hostname);
    del_hosts_conf($hostname);    

    return;
}

sub process_rekey_host {
    my ($host_list) = @_;

    my @hosts = split /,/, $host_list;
    for my $hostname (@hosts) {
        get_host_line($hostname) or die "Hostname '$hostname' not defined\n";

        $log{'message'} = "Rekeying host '$hostname'";
        print "LOGGER - process_rekey_host\n";
        use Data::Dumper; print Data::Dumper::Dumper(\%log);

        my %params = get_params($hostname);

        my $timestamp = backup_key($hostname);
        my ($password, $remoteid) = gen_key($hostname);
        add_remote_key($hostname);
        process_host_list($hostname, $timestamp);
        del_remote_key($hostname);
        process_host_list($hostname);
        del_hosts_conf($hostname, $timestamp);
        add_hosts_conf($hostname, $params{'username'}, $params{'ipaddr'}, $password, $remoteid);
    }

    return;
}

sub get_host_line {
    my ($host) = @_;

    my ($handle, $line, $host_line);
    open $handle, '<', $hosts_conf or die "Failed to open '$hosts_conf': $!\n";
    while ($line = <$handle>) {
        if ($line =~ /^${host}::/) {
            $host_line = $line;
        }
    }
    close $handle;

    return $host_line;
}

sub get_params {
    my ($host) = @_;

    chomp(my $host_line = get_host_line($host));
    my @split = split /::/, $host_line;

    my %params;
    $params{'hostname'} = $split[0];
    $params{'username'} = $split[1];
    $params{'ipaddr'}   = $split[2];
    $params{'password'} = $split[3];
    $params{'remoteid'} = $split[4];
    $params{'private'}  = "$keys_dir/$params{'hostname'}";
    $params{'public'}   = "$params{'private'}.pub";

    return %params;
}

sub gen_key {
    my ($hostname) = @_;

    if (-e "$keys_dir/$hostname" or -e "$keys_dir/$hostname.pub") {
        die "Keys already exist\n";
    }

    open my $handle, "$genpass -c2 -S0 -l32|" or die "Failed to generate password: $!\n";
    chomp(my @lines = <$handle>);
    close $handle;

    my ($password, $remoteid) = @lines;

    `$keygen -q -b 4096 -t rsa -P "$password" -C "$remoteid" -f "$keys_dir/$hostname"`;
    if ($!) {
        die "Failed to generate SSH keys for '$hostname': $!\n";
    }

    chmod 0600, "$keys_dir/$hostname", "$keys_dir/$hostname.pub"
      or die "Failed to correct permissions on '$keys_dir/$hostname\{,.pub\}'\n";

    return ($password, $remoteid);
}

sub copy_key {
    my ($hostname, $username, $ipaddr) = @_;
    
    my $out = `$copyid -i $keys_dir/$hostname.pub $username\@$ipaddr`;
    if ($? > 0) {
        die "Failed to copy SSH key to remote host '$username\@$ipaddr': $out\n";
    }

    return;
}

sub add_hosts_conf {
    my ($hostname, $username, $ipaddr, $password, $remoteid) = @_;

    open my $host_handle, '>>', $hosts_conf or die "Failed to open '$hosts_conf': $!\n";
    printf $host_handle "%s::%s::%s::%s::%s\n", $hostname, $username, $ipaddr, $password, $remoteid;
    close $host_handle;

    return;
}

sub del_hosts_conf {
    my ($hostname, $timestamp) = @_;
    
    {
        local ($^I, @ARGV) = ("." . time . ".bak", $hosts_conf);
        while (<>) {
            print unless /^${hostname}::/;
        }
    }

    if ($timestamp) {
        $hostname = "$hostname.$timestamp";
    }

    unlink "$keys_dir/$hostname" or die "Failed to unlink '$keys_dir/$hostname': $!\n";
    unlink "$keys_dir/$hostname.pub" or die "Failed to unlink '$keys_dir/$hostname.pub': $!\n";

    return;
}

sub add_remote_key { 
    my ($hostname) = @_;

    my ($key, $handle);
    open $handle, '<', "$keys_dir/$hostname.pub" or die "Failed to open '$keys_dir/$hostname.pub': $!\n";
    chomp($key = <$handle>);
    close $handle;

    my %params = get_params($hostname);
    $command = "echo '$key' >> /home/$params{'username'}/.ssh/authorized_keys";
    $args{'comment'} = "Adding SSH key to $hostname";

    return;
}

sub del_remote_key {
    my ($hostname) = @_;

    my %params = get_params($hostname);
    $command = "sed -i '/$params{'remoteid'}\$/d' /home/$params{'username'}/.ssh/authorized_keys";
    $args{'comment'} = "Removing SSH key from $hostname";

    return;
}

sub backup_key {
    my ($hostname) = @_;

    my $timestamp = time;

    rename "$keys_dir/$hostname", "$keys_dir/$hostname.$timestamp"
      or die "Failed to backup '$keys_dir/$hostname': $!\n";
    rename "$keys_dir/$hostname.pub", "$keys_dir/$hostname.$timestamp.pub"
      or die "Failed to backup '$keys_dir/$hostname.pub': $!\n";

    return $timestamp;
}

