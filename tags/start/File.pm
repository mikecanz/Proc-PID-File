package Proc::PID::File;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(hold_pid_file release_the_pid_file);
@EXPORT_OK = qw(
	pid_file_set pid_file_read pid_file_write pid_file_alive pid_file_remove
	);
use Fcntl qw(:DEFAULT :flock);

use strict;
use vars qw($VERSION);
$VERSION = '0.055';

my $self;
my $RUNDIR = "/var/run";
my $ME = $0; $ME =~ s|.*/||;

# -- Procedural Interface ----------------------------------------------------

sub pid_file_set {
	my $dir = shift || $RUNDIR;
	my $name = shift || $ME;
	$self->{path} = sprintf("%s/%s.pid", $dir, $name);
	}

sub pid_file_read {
	local *FH;
	my $path = $self->{path} || die "No file set";

	sysopen FH, $path, O_RDWR|O_CREAT
		|| die "Cannot open pid file '$path': $!\n";
	flock FH, LOCK_EX;
	my ($pid) = <FH> =~ /^(\d+)/;
	close FH;
	return $pid;
	}

sub pid_file_write {
	local *FH;
	my $path = $self->{path} || die "No file set";

	sysopen FH, $path, O_RDWR|O_CREAT
		|| die "Cannot open pid file '$path': $!\n";
	flock FH, LOCK_EX;
	sysseek  FH, 0, 0;
	truncate FH, 0;
	syswrite FH, "$$\n", length("$$\n");
	close FH || die "Cannot write pid file '$path': $!\n";
	return 0;
	}
	
sub pid_file_alive {
	my $pid = pid_file_read();
	return $pid if $pid && $pid != $$ && kill(0, $pid);
	pid_file_write();
	}
	
sub pid_file_remove {
	my $self = shift || $self;
	my $path = $self->{path} || die "No file set";
	return unless -w $path;

	sysopen FH, $path, O_RDWR || return warn $!;
	flock FH, LOCK_EX;
	unlink $path && close FH || return warn $!;
	}

# -- Old procedural interface ------------------------------------------------

sub hold_pid_file {
	pid_file_set(shift);
	pid_file_alive();
	}

sub release_the_pid_file {
	pid_file_remove();
	}

# -- Object oriented Interface -----------------------------------------------

#	Syntax:
#		->new [opts-hash[-ref]]
#	Synopsis:
#		Creates an object to manage pid files.  Valid options
#		include the following:
#			dir		: directory to place the file (defaults to /var/run)
#			name	: process name (defaults to basename($0))

sub new {
	my $class = shift;
	$self = bless({}, $class);

	my $opts = shift;
	my %opts = !defined($opts) ? () : ref($opts) ? %$opts : ($opts, @_);
	%$self = %opts;

	pid_file_set($self->{dir}, $self->{name});

	return $self;
	}

sub alive {
	my $self = shift;
	my $pid = pid_file_read();
	return $pid if $pid && $pid != $$ && kill(0, $pid);
	pid_file_write();
	}

sub delete {
	my $self = shift;
	pid_file_remove();
	}

sub DESTROY {
	my $self = shift;
	pid_file_remove($self) if $self->{path};
	}

1;
__END__

=head1 NAME

Proc::PID::File - check whether a self process is already running

=head1 SYNOPSIS - Procedural interface

 use Proc::PID_File;

 # example 1. a nonforking program that just wants to check whether its
 # instance is already running.

 die "Already running!\n" if 
 	hold_pid_file("/tmp/grab_lots_of_news_headlines.pid");
 # ...code...
 exit; # pid file will be automatically removed here
 

 # example 2. a forking program (the daemon is the child and the parent
 # immediately exists). it wants to check whether its instance is already
 # running.

 die "Already running!\n" if
 	hold_pid_file("/var/run/mydaemon.pid");
 fork && {
 	# the parent part
 	release_the_pid_file();
 	exit; # pid file won't be removed here
 }
 # the child part
 # ...code...
 exit; # pid file will be automatically removed here


 # example 3. a forking program (the parent stays active, launches children
 # to serve requests. children exit after serving some requests). it wants
 # to check whether its instance is already running.

 die "Already running!\n" if
   hold__pid_file("/var/run/mydaemon.pid");
 while (1) {
 	if ($request = get_request()) {
 		if (fork()==0) {
 			# the child part
 			release_the_pid_file();
 			# ...code...
 			exit; # pid file won't be removed here
 		}
 	}
 exit; # pid file will be removed here

=head1 SYNOPSIS - OO interface

	use Proc::PID::File;
	$pf = Proc::PID::File->new();
	die "Already running!" if $pf->alive();
 
=head1 DESCRIPTION

A pid file is a file that contain, guess what, pid. Pids are written down to
files so that:

=over 4

=item *

a program can know whether an instance of itself is currently running

=item *

other processes can know the pid of a running program

=back

This module can be used so that your script can do the former.

=head1 FUNCTIONS

=over 4

=item * hold_pid_file($path)

The hold_pid_file() function is used by a process to write its own pid to
the pid file. If the file as specified by $path cannot be written because of
an I/O error, the function dies with an error message. If the pid file
cannot be written because it belongs to another living process (i.e., the
program's previous instance), then the function will return true (a positive
number which is the pid contained in the pid file). If the pid file has been
written successfully, the function returns 0.

hold_pid_file() also creates an object in the Proc::PID_File namespace
that is used for autodeletion of pid file (by means of the DESTROY method).
You usually do not need to know or use this object. This means that, after
you invoke hold_pid_file(), when the process exits, the pid file will be
automatically deleted. Unless release_the_pid_file() was invoked.

=item * release_the_pid_file()

The release_the_pid_file() function (FIXME: name too verbose?) sets that if
the object created by hold_pid_file() is destroyed, the pid file will not be
removed. In other words, the pid file will not be automatically deleted.
Useful in forking programs, when you do not want the pid file to be removed
by the one of the child or parent.

release_the_pid_file() will die if no pid file is currently being held
(i.e., you have not invoked hold_pid_file first).

=back

=head1 AUTHOR

Steven Haryanto <steven@haryan.to>

=head1 LICENSE

Copyright (C) 2000-2002, All rights reserved.

This module is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 HISTORY

See Changes.
