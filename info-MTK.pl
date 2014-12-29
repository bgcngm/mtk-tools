#!/usr/bin/perl

#
# script from Android-DLS WiKi
#
# changes by Bruno Martins:
#   - modified to work with MT6516 boot and recovery images (17-03-2011)
#   - included support for MT65x3 and eliminated the need of header files (16-10-2011)
#   - included support for MT65xx logo images (31-07-2012)
#   - fixed problem unpacking logo images containing more than nine packed rgb565 raw files (29-11-2012)
#   - re-written logo images file verification (29-12-2012)
#   - image resolution is now calculated and shown when unpacking logo images (02-01-2013)
#   - added colored screen output (04-01-2013)
#   - included support for logo images containing uncompressed raw files (06-01-2013)
#   - more verbose output when unpacking boot and recovery images (13-01-2013)
#   - kernel or ramdisk extraction only is now supported (13-01-2013)
#   - re-written check of needed binaries (13-01-2013)
#   - ramdisk.cpio.gz deleted after successful extraction (15-01-2013)
#   - added rgb565 <=> png images conversion (27-01-2013)
#   - code cleanup and revised verbose output (16-10-2014)
#   - boot or recovery is now extracted to the working directory (16-10-2014)
#   - unpack result is stored on the working directory, despite of the input file path (17-10-2014)
#

use v5.14;
use warnings;
use bytes;
use File::Path;
use File::Basename;
use Compress::Zlib;
use Term::ANSIColor;
use Scalar::Util qw(looks_like_number);
use FindBin qw($Bin);

my $version = "Info MTK by Liviu Caramida for Bruno Martins MTK-Tools\n(last update: 28-12-2014)\n";
my $usage = "info-MTK.pl <infile>\n  Check sizes and offsets for  MediaTek boot and recovery image\n\n";

print colored ("$version", 'bold blue') . "\n";
die "Usage: $usage" unless $ARGV[0];

my $inputfile = $ARGV[0];

open (INPUTFILE, "$inputfile")
	or die_msg("couldn't open the specified file '$inputfile'!");
my $input;
while (<INPUTFILE>) {
	$input .= $_;
}
close (INPUTFILE);

if (substr($input, 0, 7) eq "\x41\x4e\x44\x52\x4f\x49\x44") {
	print " Valid Android signature found...\n\n";
	info_boot();
} else {
	die_msg("the input file does not appear to be supported or valid!");
}

sub info_boot {
	my $info = "bootimg-info" . (($^O eq "cygwin") ? ".exe" : (($^O eq "darwin") ? ".osx" : ""));
	die_msg("couldn't execute '$info' binary!\nCheck if file exists or its permissions.")
		unless (-x "$Bin/$info");
	system ("$Bin/$info $inputfile");

	print colored ("\nSuccessfully printed image informations.", 'green') . "\n";
}

sub die_msg {
	die colored ("\nError: $_[0]", 'red') . "\n";
}

