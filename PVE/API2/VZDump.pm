package PVE::API2::VZDump;

use strict;
use warnings;
use PVE::Exception qw(raise_param_exc);
use PVE::Tools qw(extract_param);
use PVE::Cluster qw(cfs_register_file cfs_read_file);
use PVE::INotify;
use PVE::RPCEnvironment;
use PVE::AccessControl;
use PVE::JSONSchema qw(get_standard_option);
use PVE::Storage;
use PVE::VZDump;
use PVE::VZDump::Common;
use PVE::API2Tools;

use Data::Dumper; # fixme: remove


use base qw(PVE::RESTHandler);

__PACKAGE__->register_method ({
    name => 'vzdump',
    path => '',
    method => 'POST',
    description => "Create backup.",
    permissions => {
	description => "The user needs 'VM.Backup' permissions on any VM, and 'Datastore.AllocateSpace' on the backup storage. The 'maxfiles', 'prune-backups', 'tmpdir', 'dumpdir', 'script', 'bwlimit' and 'ionice' parameters are restricted to the 'root\@pam' user.",
	user => 'all',
    },
    protected => 1,
    proxyto => 'node',
    parameters => {
    	additionalProperties => 0,
	properties => PVE::VZDump::Common::json_config_properties({
	    stdout => {
		type => 'boolean',
		description => "Write tar to stdout, not to a file.",
		optional => 1,
	    },
        }),
    },
    returns => { type => 'string' },
    code => sub {
	my ($param) = @_;

	my $rpcenv = PVE::RPCEnvironment::get();

	my $user = $rpcenv->get_user();

	my $nodename = PVE::INotify::nodename();

	if ($rpcenv->{type} ne 'cli') {
	    raise_param_exc({ node => "option is only allowed on the command line interface."})
		if $param->{node} && $param->{node} ne $nodename;

	    raise_param_exc({ stdout => "option is only allowed on the command line interface."})
		if $param->{stdout};
	}

	foreach my $key (qw(maxfiles prune-backups tmpdir dumpdir script bwlimit ionice)) {
	    raise_param_exc({ $key => "Only root may set this option."})
		if defined($param->{$key}) && ($user ne 'root@pam');
	}

	PVE::VZDump::verify_vzdump_parameters($param, 1);

	# silent exit if we run on wrong node
	return 'OK' if $param->{node} && $param->{node} ne $nodename;

	my $cmdline = PVE::VZDump::Common::command_line($param);

	my $vmids_per_node = PVE::VZDump::get_included_guests($param);

	my $local_vmids = delete $vmids_per_node->{$nodename} // [];

	# include IDs for deleted guests, and visibly fail later
	my $orphaned_vmids = delete $vmids_per_node->{''} // [];
	push @{$local_vmids}, @{$orphaned_vmids};

	my $skiplist = [ map { @$_ } values $vmids_per_node->%* ];

	if($param->{stop}){
	    PVE::VZDump::stop_running_backups();
	    return 'OK' if !scalar(@{$local_vmids});
	}

	# silent exit if specified VMs run on other nodes
	return "OK" if !scalar(@{$local_vmids}) && !$param->{all};

	PVE::VZDump::parse_mailto_exclude_path($param);

	die "you can only backup a single VM with option --stdout\n"
	    if $param->{stdout} && scalar(@{$local_vmids}) != 1;

	$rpcenv->check($user, "/storage/$param->{storage}", [ 'Datastore.AllocateSpace' ])
	    if $param->{storage};

	my $worker = sub {
	    my $upid = shift;

	    $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = $SIG{HUP} = $SIG{PIPE} = sub {
		die "interrupted by signal\n";
	    };

	    $param->{vmids} = $local_vmids;
	    my $vzdump = PVE::VZDump->new($cmdline, $param, $skiplist);

	    my $LOCK_FH = eval {
		$vzdump->getlock($upid); # only one process allowed
	    };
	    if (my $err = $@) {
		$vzdump->sendmail([], 0, $err);
		exit(-1);
	    }

	    if (defined($param->{ionice})) {
		if ($param->{ionice} > 7) {
		    PVE::VZDump::run_command(undef, "ionice -c3 -p $$");
		} else {
		    PVE::VZDump::run_command(undef, "ionice -c2 -n$param->{ionice} -p $$");
		}
	    }
	    $vzdump->exec_backup($rpcenv, $user);

	    close($LOCK_FH);
	};

	open STDOUT, '>/dev/null' if $param->{quiet} && !$param->{stdout};
	open STDERR, '>/dev/null' if $param->{quiet};

	if ($rpcenv->{type} eq 'cli') {
	    if ($param->{stdout}) {

		open my $saved_stdout, ">&STDOUT"
		    || die "can't dup STDOUT: $!\n";

		open STDOUT, '>&STDERR' ||
		    die "unable to redirect STDOUT: $!\n";

		$param->{stdout} = $saved_stdout;
	    }
	}

	my $taskid;
	$taskid = $local_vmids->[0] if scalar(@{$local_vmids}) == 1;

	return $rpcenv->fork_worker('vzdump', $taskid, $user, $worker);
   }});

__PACKAGE__->register_method ({
    name => 'extractconfig',
    path => 'extractconfig',
    method => 'GET',
    description => "Extract configuration from vzdump backup archive.",
    permissions => {
	description => "The user needs 'VM.Backup' permissions on the backed up guest ID, and 'Datastore.AllocateSpace' on the backup storage.",
	user => 'all',
    },
    protected => 1,
    proxyto => 'node',
    parameters => {
	additionalProperties => 0,
	properties => {
	    node => get_standard_option('pve-node'),
	    volume => {
		description => "Volume identifier",
		type => 'string',
		completion => \&PVE::Storage::complete_volume,
	    },
	},
    },
    returns => { type => 'string' },
    code => sub {
	my ($param) = @_;

	my $volume = extract_param($param, 'volume');

	my $rpcenv = PVE::RPCEnvironment::get();
	my $authuser = $rpcenv->get_user();

	my $storage_cfg = PVE::Storage::config();
	PVE::Storage::check_volume_access($rpcenv, $authuser, $storage_cfg, undef, $volume);

	return PVE::Storage::extract_vzdump_config($storage_cfg, $volume);
    }});

1;
