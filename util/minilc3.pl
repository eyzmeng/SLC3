#!perl

use 5.010;
use strict;
use warnings;

use Mini::LC3;

my $lc3 = Mini::LC3->new();

# If invoked as a file, the user most definitely
# don't know what we do here.
@ARGV or die "usage: $0 object [object...]\n";

foreach my $file (@ARGV) {
	open my $fh, '<', $file or die "$!";
	my $size = $lc3->load($file, $fh);
	close $fh;
}

use Time::HiRes qw(usleep);
my $inst = 0;
# The last ORIG address is used as our starting PC.
while (!$lc3->halted()) {
	!($lc3->step()) or die "LC-3 error: ", $lc3->error(), "\n";
	$inst++;
}
