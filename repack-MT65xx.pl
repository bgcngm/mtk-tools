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
#   - added rgb565 <=> png images conversion (27-01-2013)
#

use v5.14;
use warnings;
use Cwd;
use Compress::Zlib;
use Term::ANSIColor;
use FindBin qw($Bin);
use File::Basename;

my $dir = getcwd;

my $version = "MTK-Tools by Bruno Martins\nMT65xx repack script (last update: 27-01-2013)\n";
my $usage = "repack-MT65xx.pl COMMAND [...]\n\nCOMMANDs are:\n\n  -boot <kernel> <ramdisk-directory> <outfile>\n    Repacks boot image\n\n  -recovery <kernel> <ramdisk-directory> <outfile>\n    Repacks recovery image\n\n  -logo [--no_compression] <logo-directory> <outfile>\n    Repacks logo image\n\n";

print colored ("$version", 'bold blue') . "\n";
die "Usage: $usage" unless $ARGV[0] && $ARGV[1] && $ARGV[2];

if ( $ARGV[0] eq "-boot" || $ARGV[0] eq "-recovery" ) {
	die "Usage: $usage" unless $ARGV[3] && !$ARGV[4];
	repack_boot();
} elsif ( $ARGV[0] eq "-logo" ) {
	if ( $ARGV[1] eq "--no_compression" ) {
		die "Usage: $usage" unless $ARGV[2] && $ARGV[3] && !$ARGV[4];
	} else {
		die "Usage: $usage" unless !$ARGV[3];
		splice (@ARGV, 1, 0, "--compression"); 
	}
	shift (@ARGV);
	repack_logo();
} else {
	die "Usage: $usage";
}

sub repack_boot {
	my ($type, $kernel, $ramdiskdir, $outfile) = @ARGV;
	$type =~ s/^-//;
	$ramdiskdir =~ s/\/$//;
	my $signature = ($type eq "boot" ? "ROOTFS" : "RECOVERY");
	
	die colored ("Error: file '$kernel' not found", 'red') . "\n" unless ( -e $kernel );
	chdir $ramdiskdir or die colored ("Error: directory '$ramdiskdir' not found", 'red') . "\n";

	foreach my $tool ("find", "cpio", "gzip") {
		die colored ("Error: $tool binary not found!", 'red') . "\n"
			if system ("command -v $tool >/dev/null 2>&1");
	}
	print "Repacking $type image...\nRamdisk size: ";
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

	print "\nRepacked $type image into '$outfile'.\n";
}

sub repack_logo {
	my ($type, $logodir, $outfile) = @ARGV;
	my ($logobin, $logo_length);
	my (@raw_addr, @raw, @zlib_raw);
	$logodir =~ s/\/$//;

	my $compression = ($type eq "--no_compression" ? 0 : 1);
	my $filename = $logodir =~ s/-unpacked$//r;

	chdir $logodir or die colored ("Error: directory '$logodir' not found", 'red') . "\n";

	my $i = 0;
	printf ("Repacking logo image%s...\n", $compression ? "" : " (without compression)" );
	for my $inputfile ( glob "./$filename-img[*.*" ) {
		my $extension = (fileparse($inputfile, qr/\.[^.]*/))[2];
		$inputfile =~ s/^.\///;
		
		if ($extension eq ".png") {
			die colored ("Error: ImageMagick not found!", 'red') . "\n"
				if system ("command -v convert >/dev/null 2>&1");

			print "Converting and packing '$inputfile'\n";
			$raw[$i] = png_to_rgb565($inputfile);
		} elsif ($extension eq ".rgb565") {
			open (RGB565FILE, "$inputfile") or die colored ("Error: could not open image '$inputfile'", 'red') . "\n";
			my $input;
				while (<RGB565FILE>) {
				$input .= $_;
			}
			close (RGB565FILE);
			print "Packing '$inputfile'\n";
			$raw[$i] = $input;
		} else {
			next;
		}

		if ($compression) {
			# deflate all rgb565 images (compress zlib rfc1950)
			$zlib_raw[$i] = compress($raw[$i],Z_BEST_COMPRESSION);
		}

		$i++;
	}
	die colored ("Error: could not find any .png or .rgb565 file under the specified directory '$logodir'", 'red') . "\n" unless $i > 0;

	chdir $dir or die "\n$logodir $!";;

	my $num_blocks = $i;
	print "Number of images found and packed into new logo image: $num_blocks\n";

	if ($compression) {
		$logo_length = (4 + 4 + $num_blocks * 4);
		# calculate the start address of each rgb565 image and the new file size
		for my $i (0 .. $num_blocks - 1) {
			$raw_addr[$i] = $logo_length;
			$logo_length += length($zlib_raw[$i]);
		}

		$logobin = pack('L L', $num_blocks, $logo_length);
	
		for my $i (0 .. $num_blocks - 1) {
			$logobin .= pack('L', $raw_addr[$i]);
		}

		for my $i (0 .. $num_blocks - 1) {
			$logobin .= $zlib_raw[$i];
		}
	} else {
		for my $i (0 .. $num_blocks - 1) {
			$logobin .= $raw[$i];
		}
		$logo_length = length($logobin);
	}
	# generate logo header according to the logo size
	my $logo_header = gen_header("LOGO", $logo_length);

	$logobin = $logo_header . $logobin;

	# create the output file
	open (LOGOFILE, ">$outfile");
	binmode (LOGOFILE);
	print LOGOFILE $logobin or die;
	close (LOGOFILE);

	print "\nRepacked logo image into '$outfile'.\n";
}

sub gen_header {
	my ($header_type, $length) = @_;

	return pack('a4 L a32 a472', "\x88\x16\x88\x58", $length, $header_type, "\xFF"x472);
}

sub png_to_rgb565 {
	my $filename = $_[0] =~ s/.png$//r;
	my ($rgb565_data, $data, @encoded);

	# convert png into raw rgb (rgb888)
	system ("convert -depth 8 $filename.png rgb:$filename.raw");

	# convert raw rgb (rgb888) into rgb565
	open (RAWFILE, "$filename.raw") or die colored ("Error: could not open image '$filename.raw'", 'red') . "\n";
	binmode (RAWFILE);
	while (read (RAWFILE, $data, 3) != 0) {
		@encoded = unpack('C3', $data);
		$rgb565_data .= pack('S', (($encoded[0] >> 3) << 11) | (($encoded[1] >> 2) << 5) | ($encoded[2] >> 3));
	}
	close (RAWFILE);

	# cleanup
	system ("rm $filename.raw");

	return $rgb565_data;
}
