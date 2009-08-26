# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "Testing without -T\n"; print "1..12\n"; }
END {print "not ok 1\n" unless $loaded;}
use Proc::PID_File;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

unlink "test.pid";

sleep 1;

if (fork==0) {
	# pid file does not exist yet, so we can hold it
	print hold_pid_file("test.pid") ? "not ok":"ok", " 2\n";

	# the pid file should exist now
	print -f "test.pid" ? "ok":"not ok", " 3\n";
	
	if (fork==0) {
		# another process wants to hold it, so surely it can't
		print hold_pid_file("test.pid") ? "ok":"not ok", " 4\n";

		# the pid file still exists...
		print -f "test.pid" ? "ok":"not ok", " 5\n";
		exit;
	} else {
		wait;
	}
	
	# but now it's been deleted by the child
	print -f "test.pid" ? "not ok":"ok", " 6\n";
	exit;
} else {
	wait;
}

if (fork==0) {
	# pid file does not exist yet, so we can hold it
	print hold_pid_file("test.pid") ? "not ok":"ok", " 7\n";

	# the pid file should exist now
	print -f "test.pid" ? "ok":"not ok", " 8\n";
	
	if (fork==0) {
		# another process wants to hold it, so surely it can't
		print hold_pid_file("test.pid") ? "ok":"not ok", " 9\n";

		# the pid file still exists
		print -f "test.pid" ? "ok":"not ok", " 10\n";
		
		# we release the pid file so it will not be automatically deleted
		release_the_pid_file();
		exit;
	} else {
		wait;
	}
	
	# now the pid file should still exist
	print -f "test.pid" ? "ok":"not ok", " 11\n";
	exit;
} else {
	wait;
}

# the pid file should not exist now
print -f "test.pid" ? "not ok":"ok", " 12\n";

system "./test-T.pl";

