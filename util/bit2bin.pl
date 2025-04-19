#!/usr/bin/env perl

=head1 NAME

bit2bin - from object file back to LC-3 tutor raw format

=head1 SYNOPSIS

bit2bin [infile [outfile]]

=head1 BUGS

May be plenty, but I (ethan) am not checking today...

=cut

use 5.010;
use strict;
use warnings;

my $fout = undef;
my $fout_new = 0;
my $fin = undef;
my $fin_new = 0;

if (@ARGV > 2) {
	print STDERR "usage: $0 [infile [outfile]]\n";
	exit 1;
}
# FIXME: "-" should be taken as stdin/stdout
# for consistency with the improved bin2bit.c
if (@ARGV) {
	my $file = shift;
	unless (open $fin, '<', $file) {
		print STDERR "open for read: $file: $!\n";
		exit 1;
	}
	$fin_new = 1;
	binmode $fin;
}
if (@ARGV) {
	my $file = shift;
	unless (open $fout, '>', $file) {
		close $fin if $fin_new;
		print STDERR "open for write $file: $!\n";
		exit 1;
	}
}

defined $fin or $fin = \*STDIN;
defined $fout or $fout = \*STDOUT;

my $n = 0; my $ow;
while (read $fin, $ow, 1) {
	# XXX: handle fwrite(3) errors???
	printf $fout "%08b", ord($ow);
	print $fout "\n" if $n % 2;
	$n++;
}
unless (defined $ow) {
	close $fout if $fout_new;
	close $fin if $fin_new;
	printf STDERR "read: $!\n";
	exit 1;
}
print $fout "\n" if $n % 2;
$fout->flush();

close $fout if $fout_new;
close $fin if $fin_new;

print STDERR "Serialized ${n} octet@{['s' x !!($n != 1)]}\n";
