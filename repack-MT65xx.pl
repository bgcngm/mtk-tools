#!/usr/bin/perl

#
# script from Android-DLS WiKi
#
# changes by Bruno Martins:
#   - modified to work with MT6516 boot and recovery images (17-03-2011)
#   - included support for MT65x3 and eliminated the need of header files (16-10-2011)
#   - added cygwin mkbootimg binary and propper fix (17-05-2012)
#   - included support for MT65xx logo images (31-07-2012)
#   - added colored screen output (04-01-2013)
#   - included support for logo images containing uncompressed raw files (06-01-2013)
#   - re-written check of needed binaries (13-01-2013)
#

use strict;
use warnings;
use Cwd;
use Compress::Zlib;
use Term::ANSIColor;
use FindBin qw($Bin);

my $dir = getcwd;

my $version = "MTK-Tools by Bruno Martins\nMT65xx repack script (last update: 20-01-2013)\n";
my $usage = "repack-MT65xx.pl COMMAND [...]\n\nCOMMANDs are:\n\n  -boot <kernel> <ramdisk-directory> <outfile>\n    Repacks boot image\n\n  -recovery <kernel> <ramdisk-directory> <outfile>\n    Repacks recovery image\n\n  -logo [--no_compression] <logo-directory> <outfile>\n    Repacks logo image\n\n";

print colored ("$version", 'bold blue') . "\n";
die "Usage: $usage" unless $ARGV[0] && $ARGV[1] && $ARGV[2];

if ( $ARGV[0] eq "-boot" ) {
	die "Usage: $usage" unless $ARGV[3] && !$ARGV[4];
	repack_boot("ROOTFS");
} elsif ( $ARGV[0] eq "-recovery" ) {
	die "Usage: $usage" unless $ARGV[3] && !$ARGV[4];
	repack_boot("RECOVERY");
} elsif ( $ARGV[0] eq "-logo" ) {
	if ( $ARGV[1] eq "--no_compression" ) {
		die "Usage: $usage" unless $ARGV[2] && $ARGV[3] && !$ARGV[4];
		repack_logo_uncompressed("LOGO");
	}
	else {
		die "Usage: $usage" unless !$ARGV[3];
		repack_logo("LOGO");
	}
} else {
	die "Usage: $usage";
}

sub repack_boot {
	my $kernel = $ARGV[1];
	my $ramdiskdir = $ARGV[2];
	my $outfile = $ARGV[3];
	my $signature = $_[0];
	$ARGV[0] =~ s/-//;
	
	die colored ("Error: file '$kernel' not found", 'red') . "\n" unless ( -e $kernel );
	chdir $ramdiskdir or die colored ("Error: directory '$ramdiskdir' not found", 'red') . "\n";

	foreach my $tool ("find", "cpio", "gzip") {
		die colored ("Error: $tool binary not found!", 'red') . "\n"
			if system ("command -v $tool >/dev/null 2>&1");
	}
	print "Repacking $ARGV[0] image...\nRamdisk size: ";
	system ("find . | cpio -o -H newc | gzip > $dir/ramdisk-repack.cpio.gz");

	chdir $dir or die "\n$ramdiskdir $!";;

	open (RAMDISKFILE, "ramdisk-repack.cpio.gz") or die colored ("Error: could not open ramdisk file 'ramdisk-repack.cpio.gz'", 'red') . "\n";
	my $ramdisk;
	while (<RAMDISKFILE>) {
		$ramdisk .= $_;
	}
	close (RAMDISKFILE);

	# generate the header according to the ramdisk size
	my $sizeramdisk = length($ramdisk);
	my $header = gen_header($signature, $sizeramdisk);

	# attach the header to ramdisk
	my $newramdisk = $header . $ramdisk;

	open (RAMDISKFILE, ">new-ramdisk-repack.cpio.gz");
	binmode (RAMDISKFILE);
	print RAMDISKFILE $newramdisk or die;
	close (RAMDISKFILE);

	# create the output file
	if ( $^O eq "cygwin" ) {
		system ("$Bin/mkbootimg.exe --kernel $kernel --ramdisk new-ramdisk-repack.cpio.gz -o $outfile");
	} else {
		system ("$Bin/mkbootimg --kernel $kernel --ramdisk new-ramdisk-repack.cpio.gz -o $outfile");
	}

	# cleanup
	unlink ("ramdisk-repack.cpio.gz") or die $!;
	system ("rm new-ramdisk-repack.cpio.gz");

	print "\nRepacked $ARGV[0] image into '$outfile'.\n";
}

sub repack_logo {
	my $logodir = $ARGV[1];
	my $outfile = $ARGV[2];
	my $signature = $_[0];
	$ARGV[0] =~ s/-//;

	chdir $logodir or die colored ("Error: directory '$logodir' not found", 'red') . "\n";

	my (@raw_addr, @zlib_raw) = ();

	my $i = 0;
	print "Repacking $ARGV[0] image...\n";
	for my $inputfile ( glob "./*.rgb565" ) {
		open (INPUTFILE, "$inputfile") or die colored ("Error: could not open raw image '$inputfile'", 'red') . "\n";
		my $input;
			while (<INPUTFILE>) {
			$input .= $_;
		}
		close INPUTFILE;

		# deflate all rgb565 raw files found (compress zlib rfc1950)
		$zlib_raw[$i] = compress($input,Z_BEST_COMPRESSION);

		$i++;
	}
	die colored ("Error: could not find any .rgb565 file under the specified directory '$logodir'", 'red') . "\n" unless $i > 0;

	chdir $dir or die "\n$logodir $!";;

	my $num_blocks = $i;
	print "Number of raw images found in the specified folder: $num_blocks\n";
	
	my $logo_length = (4 + 4 + $num_blocks * 4);
	# calculate the start address of each raw image and the new file size
	for my $i (0 .. $num_blocks - 1) {
		$raw_addr[$i] = $logo_length;
		$logo_length += length($zlib_raw[$i]);
	}

	# generate logo header according to the logo size
	my $logo_header = gen_header($signature, $logo_length);
	
	my $logobin = pack('L L', $num_blocks, $logo_length);
	
	for my $i (0 .. $num_blocks - 1) {
		$logobin .= pack('L', $raw_addr[$i]);
	}

	for my $i (0 .. $num_blocks - 1) {
		$logobin .= $zlib_raw[$i];
	}

	$logobin = $logo_header . $logobin;

	# create the output file
	open (LOGOFILE, ">$outfile");
	binmode (LOGOFILE);
	print LOGOFILE $logobin or die;
	close (LOGOFILE);

	print "\nRepacked $ARGV[0] image into '$outfile'.\n";
}

sub repack_logo_uncompressed {
	my @raw;
	my $logodir = $ARGV[2];
	my $outfile = $ARGV[3];
	my $signature = $_[0];
	$ARGV[0] =~ s/-//;

	chdir $logodir or die colored ("Error: directory '$logodir' not found", 'red') . "\n";

	my $i = 0;
	print "Repacking $ARGV[0] image (without compression)...\n";
	for my $inputfile ( glob "./*.rgb565" ) {
		open (INPUTFILE, "$inputfile") or die colored ("Error: could not open raw image '$inputfile'", 'red') . "\n";
		while (<INPUTFILE>) {
			$raw[$i] .= $_;
		}
		close INPUTFILE;

		$i++;
	}
	die colored ("Error: could not find any .rgb565 file under the specified directory '$logodir'", 'red') . "\n" unless $i > 0;

	chdir $dir or die "\n$logodir $!";;
	
	my $num_blocks = $i;
	print "Number of raw images found in the specified folder: $num_blocks\n";

	my $logobin;
	for my $i (0 .. $num_blocks - 1) {
		$logobin .= $raw[$i];
	}
	
	# generate logo header according to the logo size
	my $logo_header = gen_header($signature, length($logobin));
	
	$logobin = $logo_header . $logobin;

	# create the output file
	open (LOGOFILE, ">$outfile");
	binmode (LOGOFILE);
	print LOGOFILE $logobin or die;
	close (LOGOFILE);

	print "\nRepacked $ARGV[0] image into '$outfile'.\n";
}

sub gen_header {
	my ($header_type, $length) = @_;

	return pack('a4 L a32 a472', "\x88\x16\x88\x58", $length, $header_type, "\xFF"x472);
}
