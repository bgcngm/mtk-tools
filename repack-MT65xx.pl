#!/usr/bin/perl -W

# script from Android-DLS WiKi
# modified for MT6516 by Bruno Martins

use strict;
use Cwd;


my $dir = getcwd;

my $usage = "repack-bootimg.pl <kernel> <ramdisk-header> <ramdisk-directory> <outfile>\n";

die "\nUsage:\n\n$usage" unless $ARGV[0] && $ARGV[1] && $ARGV[2] && $ARGV[3];

chdir $ARGV[2] or die "$ARGV[2] $!";

system ("find . | cpio -o -H newc | gzip > $dir/ramdisk-repack.cpio.gz");

chdir $dir or die "$ARGV[2] $!";;

open (HEADERFILE, "$ARGV[1]") or die "could not open ramdisk header file: $ARGV[1]\n";
my $header = <HEADERFILE>;
close HEADERFILE;

my $slurpvar = $/;
undef $/;
open (RAMDISKFILE, "ramdisk-repack.cpio.gz") or die "could not open ramdisk file: ramdisk-repack.cpio.gz\n";
my $ramdisk = <RAMDISKFILE>;
close RAMDISKFILE;
$/ = $slurpvar;

my $sizeramdisk = -s 'ramdisk-repack.cpio.gz';
my $hexsizeramdisk = sprintf("%08X", $sizeramdisk);
$header = pack("a4 H8", substr($header,0,4), substr($hexsizeramdisk,6) . substr($hexsizeramdisk,4,-2) . substr($hexsizeramdisk,2,-4) . substr($hexsizeramdisk,0,-6)) . substr($header,8);
#$header =~ s/\x51\xF1\x04\x00/\x11\x11\x11\x11/sgx;
my $newramdisk = $header . $ramdisk;

open (RAMDISKFILE, ">new-ramdisk-repack.cpio.gz");
print RAMDISKFILE $newramdisk or die;
close RAMDISKFILE;

# system ("mkbootimg --kernel $ARGV[0] --ramdisk ramdisk-repack.cpio.gz --base 0x30000000 --pagesize 4096 -o $ARGV[3]");
system ("./mkbootimg --kernel $ARGV[0] --ramdisk new-ramdisk-repack.cpio.gz -o $ARGV[3]");

unlink("ramdisk-repack.cpio.gz") or die $!;
system("rm new-ramdisk-repack.cpio.gz");

print "\nrepacked boot image written at $ARGV[3]\n";
