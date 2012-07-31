#!/usr/bin/perl -W

# script from Android-DLS WiKi
# modified for MT6516 by Bruno Martins

use strict;
use bytes;
use File::Path;

my $usage = "repack-bootimg.pl <boot image>\n";

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

# get the ramdisk header (rootfs signature for boot images / recovery signature for recovery images)
my($ramdiskheader) = substr($ram1, 0, 512);

open (HEADERFILE, ">$ARGV[0]-ramdisk.header");
binmode(HEADERFILE);
print HEADERFILE $ramdiskheader or die;
close HEADERFILE;

print "\nramdisk header written to $ARGV[0]-ramdisk.header\n";

# chop ramdisk header
$ram1 = substr($ram1, 512);

if (substr($ram1, 0, 2) ne "\x1F\x8B")
{
        die "the boot image does not appear to contain a valid gzip file";
}

open (RAM1FILE, ">$ARGV[0]-ramdisk.cpio.gz");
binmode(RAM1FILE);
print RAM1FILE $ram1 or die;
close RAM1FILE;

print "\nramdisk written to $ARGV[0]-ramdisk.cpio.gz\n";

if (-e "$ARGV[0]-ramdisk") {
        rmtree "$ARGV[0]-ramdisk";
        print "\nremoved old directory $ARGV[0]-ramdisk\n";
}

mkdir "$ARGV[0]-ramdisk" or die;
chdir "$ARGV[0]-ramdisk" or die;
system ("gzip -d -c ../$ARGV[0]-ramdisk.cpio.gz | cpio -i");

print "\nextracted ramdisk contents to directory $ARGV[0]-ramdisk\n";
