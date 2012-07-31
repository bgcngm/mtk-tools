#!/usr/bin/perl -W

#
# script from Android-DLS WiKi
#
# changes by Bruno Martins:
#   - modified to work with MT6516 boot and recovery images (17-03-2011)
#   - included support for MT65x3 and eliminated the need of header files (16-10-2011)
#   - added cygwin mkbootimg binary and propper fix (17-05-2012)
#

use strict;
use Cwd;


my $dir = getcwd;

my $usage = "repack-MT65xx.pl [-recovery] <kernel> <ramdisk-directory> <outfile>\n";

# initilization
my $kernel;
my $ramdiskdir;
my $outfile;

# set default header (rootfs signature)
my $header = pack("H*","88168858a3910400524f4f5446530000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");

die "\nUsage:\n\n$usage" unless $ARGV[0] && $ARGV[1] && $ARGV[2] && !$ARGV[4];
if ( ( $ARGV[0] && $ARGV[1] && $ARGV[2] && $ARGV[3] && $ARGV[0] ne "-recovery" ) or ( $ARGV[0] eq "-recovery" && !$ARGV[3] ) ) {
	die "\nUsage:\n\n$usage";
}

if ( $ARGV[0] eq "-recovery" ) {
	# change header (recovery signature)
	$header = pack("H*","88168858a39104005245434f56455259000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
	$kernel = $ARGV[1];
	$ramdiskdir = $ARGV[2];
	$outfile = $ARGV[3];
} else {
	$kernel = $ARGV[0];
	$ramdiskdir = $ARGV[1];
	$outfile = $ARGV[2];
}

chdir $ramdiskdir or die "$ramdiskdir $!";

system ("find . | cpio -o -H newc | gzip > $dir/ramdisk-repack.cpio.gz");

chdir $dir or die "$ramdiskdir $!";;

my $slurpvar = $/;
undef $/;
open (RAMDISKFILE, "ramdisk-repack.cpio.gz") or die "could not open ramdisk file: ramdisk-repack.cpio.gz\n";
my $ramdisk = <RAMDISKFILE>;
close RAMDISKFILE;
$/ = $slurpvar;

# update header according to the new ramdisk size
my $sizeramdisk = -s 'ramdisk-repack.cpio.gz';
my $hexsizeramdisk = sprintf("%08X", $sizeramdisk);
$header = pack("a4 H8", substr($header,0,4), substr($hexsizeramdisk,6) . substr($hexsizeramdisk,4,-2) . substr($hexsizeramdisk,2,-4) . substr($hexsizeramdisk,0,-6)) . substr($header,8);
my $newramdisk = $header . $ramdisk;

open (RAMDISKFILE, ">new-ramdisk-repack.cpio.gz");
print RAMDISKFILE $newramdisk or die;
close RAMDISKFILE;

# create the outfile
if ( $^O eq "cygwin" ) {
	system ("./mkbootimg.exe --kernel $kernel --ramdisk new-ramdisk-repack.cpio.gz -o $outfile");
} else {
	system ("mkbootimg --kernel $kernel --ramdisk new-ramdisk-repack.cpio.gz -o $outfile");
}

# cleanup
unlink("ramdisk-repack.cpio.gz") or die $!;
system("rm new-ramdisk-repack.cpio.gz");

if ( $ARGV[0] eq "-recovery" ) {
	print "\nrepacked recovery image written to $outfile\n";
} else {
	print "\nrepacked boot image written to $outfile\n";
}
