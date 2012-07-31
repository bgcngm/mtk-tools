#!/usr/bin/perl -W

# script from Android-DLS WiKi
#
# changes by Bruno Martins:
#   - modified to work with MT6516 boot and recovery images (17-03-2011)
#   - included support for MT65x3 and eliminated the need of header files (16-10-2011)

use strict;
use bytes;
use File::Path;

my $usage = "unpack-MT65xx.pl <image>\n";

die "\nUsage:\n\n$usage" unless $ARGV[0];

my $bootimgfile = $ARGV[0];

my $slurpvar = $/;
undef $/;
open (BOOTIMGFILE, "$bootimgfile") or die "could not open boot img file: $bootimgfile\n";
my $bootimg = <BOOTIMGFILE>;
close BOOTIMGFILE;
$/ = $slurpvar;

my($bootMagic, $kernelSize, $kernelLoadAddr, $ram1Size, $ram1LoadAddr, $ram2Size, $ram2LoadAddr, $tagsAddr, $pageSize, $unused1, $unused2, $bootName, $cmdLine, $id) = unpack('a8 L L L L L L L L L L a16 a512 a8', $bootimg);

my($kernel) = substr($bootimg, $pageSize, $kernelSize);

open (KERNELFILE, ">$ARGV[0]-kernel.img");
binmode(KERNELFILE);
print KERNELFILE $kernel or die;
close KERNELFILE;

print "\nkernel written to $ARGV[0]-kernel.img\n";

my($kernelAddr) = $pageSize;
my($kernelSizeInPages) = int(($kernelSize + $pageSize - 1) / $pageSize);

my($ram1Addr) = (1 + $kernelSizeInPages) * $pageSize;

my($ram1) = substr($bootimg, $ram1Addr, $ram1Size);

# chop ramdisk header
$ram1 = substr($ram1, 512);

if (substr($ram1, 0, 2) ne "\x1F\x8B") {
	die "the boot image does not appear to contain a valid gzip file";
}

open (RAMDISKFILE, ">$ARGV[0]-ramdisk.cpio.gz");
binmode(RAMDISKFILE);
print RAMDISKFILE $ram1 or die;
close RAMDISKFILE;

print "\nramdisk written to $ARGV[0]-ramdisk.cpio.gz\n";

if (-e "$ARGV[0]-ramdisk") {
        rmtree "$ARGV[0]-ramdisk";
        print "\nremoved old directory $ARGV[0]-ramdisk\n";
}

mkdir "$ARGV[0]-ramdisk" or die;
chdir "$ARGV[0]-ramdisk" or die;
system ("gzip -d -c ../$ARGV[0]-ramdisk.cpio.gz | cpio -i");

print "\nextracted ramdisk contents to directory $ARGV[0]-ramdisk\n";
