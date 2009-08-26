#
#   Proc::PID::File - pidfile manager
#   Copyright (C) 2001-2003 Erick Calder
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

package Proc::PID::File;

=head1 NAME

Proc::PID::File - a module to manage process id files

=head1 SYNOPSIS

  use Proc::PID::File;
  die "Already running!" if Proc::PID::File->running();

=head1 DESCRIPTION

This Perl module is useful for writers of daemons and other processes that need to tell whether they are already running, in order to prevent multiple process instances.  The module accomplishes this via *nix-style I<pidfiles>, which are files that store a process identifier.

=cut

use strict;
use vars qw($VERSION $RPM_Requires);
use Fcntl qw(:DEFAULT :flock);

$VERSION = "1.24";
$RPM_Requires = "procps";

my $RUNDIR = "/var/run";
my $ME = $0; $ME =~ s|.*/||;

# used to keep non-expiring objects
# for simple and procedural interfaces

my $self;

# -- Interface ---------------------------------------------------------------

=head1 Module Interface

The interface consists of a single call as indicated in the B<Synopsis> section above.  This approach avoids causing race conditions whereby one instance of a daemon could read the I<pidfile> after a previous instance has read it but before it has had a chance to write to it.

=head2 running [hash[-ref]]

This method receives an optional hash (or, alternatively, a hash reference) of options, which determines function behaviour.

The returns value is true when the calling process is already running.  Please note that this call must be made *after* daemonisation i.e. subsequent to the call to fork().

The options available include the following:

=over

=item I<dir>

Specifies the directory to place the pid file.  If left unspecified, defaults to F</var/run>.

=item I<name>

Indicates the name of the current process.  When not specified, defaults to I<basename($0)>.

=item I<verify> = 1 | string

This parameter helps prevent the problem described in the WARNING section below.  If set to a string, it will be interpreted as a I<regular expression> and used to search within the name of the running process.  A 1 may also be passed, indicating that the value of I<$0> should be used (stripped of its full path).  If the parameter is not passed, no verification will take place.

Please note that verification will only work for the operating systems listed below and that the os will be auto-sensed.  See also DEPENDENCIES section below.

Supported platforms: Linux, FreeBSD

=item I<debug>

Turns debugging output on.

=back

=cut

sub running {
    $self = shift->new(@_);
	my $path = $self->{path};

    local *FH;
	sysopen(FH, $path, O_RDWR|O_CREAT)
		|| die qq/Cannot open pid file [$path]: $!\n/;
	flock(FH, LOCK_EX | LOCK_NB)
        || die "pidfile $path already locked";
	my ($pid) = <FH> =~ /^(\d+)/;

	if ($pid && $pid != $$ && kill(0, $pid)) {
        $self->debug("running: $pid");
        if ($self->verify($pid)) {
	        close FH;
	        return $pid;
            }
        }

    $self->debug("writing: $$");
	sysseek  FH, 0, 0;
	truncate FH, 0;
	syswrite FH, "$$\n", length("$$\n");
	close(FH) || die qq/Cannot write pid file "$path": $!\n/;

	return 0;
    }

sub verify {
    my ($self, $pid) = @_;
    return 1 unless $self->{verify};

    eval "use Config";
    die "$@\nCannot use the Config module.  Please install.\n" if $@;

    $self->debug("verifying on: $Config::Config{osname}");
    if ($Config::Config{osname} =~ /linux|freebsd/i) {
        my $me = $self->{verify};
        ($me = $0) =~ s|.*/|| if !$me || $me eq "1";
        my @ps = split m|$/|, qx/ps -fp $pid/
            || die "ps utility not available: $!";
        s/^\s+// for @ps;   # leading spaces confuse us

        no warnings;    # hate that deprecated @_ thing
        my $n = split(/\s+/, $ps[0]);
        @ps = split /\s+/, $ps[1], $n;
        return scalar grep /$me/, $ps[$n - 1];
        }
    }

# -- support functionality ---------------------------------------------------

sub new {
	my $class = shift;
	my $self = bless({}, $class);
	%$self = &args;

	$self->file();		# init file path

	return $self;
	}

sub file {
	my $self = shift;
	%$self = (%$self, &args);
	$self->{dir} ||= $RUNDIR;
	$self->{name} ||= $ME;
	$self->{path} = sprintf("%s/%s.pid", $self->{dir}, $self->{name});
	}

sub args {
	my $opts = shift;
	!defined($opts) ? () : ref($opts) ? %$opts : ($opts, @_);
	}

sub debug {
	my $self = shift;
	my $msg = shift || $_;

	print "> Proc::PID::File - $msg"
		if $self->{debug};
	}

sub DESTROY {
	my $self = shift;

    open(PID, $self->{path})
		|| die qq/Cannot open pid file "$self->{path}": $!\n/
        ;
	my ($pid) = <PID> =~ /^(\d+)/;
    close PID;

	unlink($self->{path}) || warn $!
        if $self->{path} && $pid && $pid == $$;
	}

1;

__END__

# -- documentation -----------------------------------------------------------

=head1 AUTHOR

Erick Calder <ecalder@cpan.org>

=head1 ACKNOWLEDGEMENTS

1k thx to Steven Haryanto <steven@haryan.to> whose package (Proc::RID_File) inspired this implementation.

Our gratitude also to Alan Ferrency <alan@pair.com> for fingering the boot-up problem and suggesting possible solutions.

=head1 DEPENDENCIES

For Linux and FreeBSD, support of the I<verify> option (simple interface) requires the B<ps> utility to be available.  This is typically found in the B<procps> RPM.

=head1 WARNING

This module may prevent daemons from starting at system boot time.  The problem occurs because the process id written to the I<pidfile> by an instance of the daemon may coincidentally be reused by another process after a system restart, thus making the daemon think it's already running.

Some ideas on how to fix this problem are catalogued below, but unfortunately, no platform-independent solutions have yet been gleaned.

=over

=item - leaving the I<pidfile> open for the duration of the daemon's life

=item - checking a C<ps> to make sure the pid is what one expects (current implementation)

=item - looking at /proc/$PID/stat for a process name

=item - check mtime of the pidfile versus uptime; don't trust old pidfiles

=item - try to get the script to nuke its pidfile when it exits (this is vulnerable to hardware resets and hard reboots)

=item - try to nuke the pidfile at boot time before the script runs; this solution suffers from a race condition wherein two instances read the I<pidfile> before one manages to lock it, thus allowing two instances to run simultaneously.

=back

=head1 SUPPORT

For help and thank you notes, e-mail the author directly.  To report a bug, submit a patch or add to our wishlist please visit the CPAN bug manager at: F<http://rt.cpan.org>

=head1 AVAILABILITY

The latest version of the tarball, RPM and SRPM may always be found at: F<http://perl.arix.com/>  Additionally the module is available from CPAN.

=head1 LICENCE

This utility is free and distributed under GPL, the Gnu Public License.  A copy of this license was included in a file called LICENSE. If for some reason, this file was not included, please see F<http://www.gnu.org/licenses/> to obtain a copy of this license.

$Id: File.pm,v 1.16 2004-04-08 02:27:25 ekkis Exp $
