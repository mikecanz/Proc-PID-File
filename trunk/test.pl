#!/usr/bin/perl -w

#
#   Proc::PID::File - test suite
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

use strict;
use warnings;

#   make sure this script can find the module
#   without being run by 'make test' (see --deamon switch below).

use lib "blib/lib";

#   set up expectations

$|++; $\ = "\n";

use Proc::PID::File;
use Test::Simple tests => 7;

my %args = ( name => "test", dir => ".", debug => $ENV{DEBUG} );
my $cmd = shift || "";

if ($cmd eq "--daemon") {
    die "Already running!" if Proc::PID::File->running(%args);
    sleep(5);
    exit();
    }

exit() if $cmd eq "--short";

ok(1, 'use Proc::PID::File'); # If we made it this far, we're ok.

unlink("test.pid") || die $! if -e "test.pid";  # blank slate
system qq|$^X $0 --daemon > /dev/null 2>&1 &|; sleep 1;
my $pid = qx/cat test.pid/; chomp $pid;

my $rc = Proc::PID::File->running(%args);
ok($rc, "running");

$rc = Proc::PID::File->running(%args, verify => 1);
ok($rc, "verified: real");

# WARNING: the following test takes over the pidfile from the
# daemon such that he cannot clean it up.  this is as it should be
# since no one but us should occupy our pidfile 

$rc = Proc::PID::File->running(%args, verify => "falsetest");
ok(! $rc, "verified: false");

sleep 1 while kill 0, $pid;

$rc = Proc::PID::File->running(%args);
ok(! $rc, "single instance");

# test DESTROY

system qq|$^X $0 --short > /dev/null 2>&1|;
ok(-f "test.pid", "destroy");

ok(1, "done");
