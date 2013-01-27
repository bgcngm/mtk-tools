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
#

use v5.14;
use warnings;
use bytes;
use File::Path;
use Compress::Zlib;
use Term::ANSIColor;
use Scalar::Util qw(looks_like_number);
use FindBin qw($Bin);

my $version = "MTK-Tools by Bruno Martins\nMT65xx unpack script (last update: 27-01-2013)\n";
my $usage = "unpack-MT65xx.pl <infile> [COMMAND ...]\n  Unpacks boot, recovery or logo image\n\nOptional COMMANDs are:\n\n  -kernel_only\n    Extract kernel only from boot or recovery image\n\n  -ramdisk_only\n    Extract ramdisk only from boot or recovery image\n\n  -force_logo_res <width> <height>\n    Forces logo image file to be unpacked by specifying image resolution,\n    which must be entered in pixels\n     (only useful when no zlib compressed images are found)\n\n  -invert_logo_res\n    Invert image resolution (width <-> height)\n     (may be useful when extracted images appear to be broken)\n\n";

print colored ("$version", 'bold blue') . "\n";
die "Usage: $usage" unless $ARGV[0];

if ( $ARGV[1] ) {
	if ( $ARGV[1] eq "-kernel_only" || $ARGV[1] eq "-ramdisk_only" || $ARGV[1] eq "-invert_logo_res" ) {
		die "Usage: $usage" unless !$ARGV[2];
	} elsif ( $ARGV[1] eq "-force_logo_res" ) {
		die "Usage: $usage" unless looks_like_number($ARGV[2]) && looks_like_number($ARGV[3]) && !$ARGV[4];
	} else {
		die "Usage: $usage";
	}
}

my $inputfile = $ARGV[0];

open (INPUTFILE, "$inputfile") or die colored ("Error: could not open the specified file '$inputfile'", 'red') . "\n";
my $input;
while (<INPUTFILE>) {
	$input .= $_;
}
close (INPUTFILE);

if ((substr($input, 0, 4) eq "\x88\x16\x88\x58") & (substr($input, 8, 4) eq "LOGO")) {
	# if the input file contains the logo signature, try to unpack it
	print "Valid logo signature found...\n";
	if ( $ARGV[1] ) {
		die colored ("\nError: $ARGV[1] switch can't be used with logo images", 'red') . "\n"
			if ($ARGV[1] ne "-force_logo_res" && $ARGV[1] ne "-invert_logo_res");
		$ARGV[1] =~ s/-//;
		unpack_logo($input, $ARGV[1]);
	} else {
		unpack_logo($input, "none");
	}
} elsif (substr($input, 0, 7) eq "\x41\x4e\x44\x52\x4f\x49\x44") {
	# else, if a valid Android signature is found, try to unpack boot or recovery image
	print "Valid Android signature found...\n";
	if ( $ARGV[1] ) {
		die colored ("\nError: $ARGV[1] switch can't be used with boot or recovery images", 'red') . "\n"
			if ($ARGV[1] ne "-kernel_only" && $ARGV[1] ne "-ramdisk_only");
		$ARGV[1] =~ s/-//;
		$ARGV[1] =~ s/_only//;
		unpack_boot($input, $ARGV[1]);
	} else {
		unpack_boot($input, "kernel and ramdisk");
	}
} else {
	die colored ("Error: the input file does not appear to be supported or valid", 'red') . "\n";
}

sub unpack_boot {
	my ($bootimg, $extract) = @_;
	my ($bootMagic, $kernelSize, $kernelLoadAddr, $ram1Size, $ram1LoadAddr, $ram2Size, $ram2LoadAddr, $tagsAddr, $pageSize, $unused1, $unused2, $bootName, $cmdLine, $id) = unpack('a8 L L L L L L L L L L a16 a512 a8', $bootimg);

	# print input file information
	print colored ("\nInput file information:\n", 'yellow') . "\n";
	print " Kernel size: $kernelSize bytes / ";
	printf ("load address: %#x\n", $kernelLoadAddr);
	print " Ramdisk size: $ram1Size bytes / ";
	printf ("load address: %#x\n", $ram1LoadAddr);
	print " Second stage size: $ram2Size bytes / ";
	printf ("load address: %#x\n", $ram2LoadAddr);
	print " Page size: $pageSize bytes\n ASCIIZ product name: '$bootName'\n";
	printf (" Command line: %s\n\n", substr($cmdLine, 0, 2) eq "\x00\x00" ? "(none)" : $cmdLine );
	
	if ( $extract eq "kernel" || $extract eq "kernel and ramdisk" ) {
		my($kernel) = substr($bootimg, $pageSize, $kernelSize);

		open (KERNELFILE, ">$ARGV[0]-kernel.img");
		binmode (KERNELFILE);
		print KERNELFILE $kernel or die;
		close (KERNELFILE);

		print "Kernel written to '$ARGV[0]-kernel.img'\n";
	}

	if ( $extract eq "ramdisk" || $extract eq "kernel and ramdisk" ) {
		my($kernelAddr) = $pageSize;
		my($kernelSizeInPages) = int(($kernelSize + $pageSize - 1) / $pageSize);

		my($ram1Addr) = (1 + $kernelSizeInPages) * $pageSize;

		my($ram1) = substr($bootimg, $ram1Addr, $ram1Size);

		# chop ramdisk header
		$ram1 = substr($ram1, 512);

		if (substr($ram1, 0, 2) ne "\x1F\x8B") {
			die colored ("\nError: the boot image does not appear to contain a valid gzip file", 'red') . "\n";
		}

		open (RAMDISKFILE, ">$ARGV[0]-ramdisk.cpio.gz");
		binmode (RAMDISKFILE);
		print RAMDISKFILE $ram1 or die;
		close (RAMDISKFILE);

		if (-e "$ARGV[0]-ramdisk") {
			rmtree "$ARGV[0]-ramdisk";
			print "Removed old ramdisk directory '$ARGV[0]-ramdisk'\n";
		}

		mkdir "$ARGV[0]-ramdisk" or die;
		chdir "$ARGV[0]-ramdisk" or die;
		foreach my $tool ("gzip", "cpio") {
			die colored ("\nError: $tool binary not found!", 'red') . "\n"
				if system ("command -v $tool >/dev/null 2>&1");
		}
		print "Ramdisk size: ";
		system ("gzip -d -c ../$ARGV[0]-ramdisk.cpio.gz | cpio -i");
		system ("rm ../$ARGV[0]-ramdisk.cpio.gz");

		print "Extracted ramdisk contents to directory '$ARGV[0]-ramdisk'\n";
	}

	print "\nSuccessfully unpacked $extract.\n";
}

sub unpack_logo {
	my ($logobin, $switch) = @_;
	my @resolution;

	# parse logo_res.txt file if it exists
	if (-e "$Bin/logo_res.txt") {
		open (LOGO_RESFILE, "$Bin/logo_res.txt") or die colored ("Error: could not open file '$Bin/logo_res.txt'", 'red') . "\n";
		while (<LOGO_RESFILE>) {
			if ($_ =~ /^\[(\d+),(\d+),(.*)\]$/) {
				if ($switch eq "invert_logo_res") {
					push (@resolution, [$2, $1, $3]);
				} else {
					push (@resolution, [$1, $2, $3]);
				}
			}
		}
		close (LOGO_RESFILE);
	}

	# check if ImageMagick is installed
	my $ImageMagick_installed = system ("command -v convert >/dev/null 2>&1") ? 0 : 1;

	# get logo header
	my $header = substr($logobin, 0, 512);
	my ($header_sig, $logo_length, $logo_sig) = unpack('a4 V A4', $header);

	# throw a warning if logo file size is not what is expected
	# (it may happen if logo image was created with a backup tool and contains trailing zeros)
	my $sizelogobin = -s $inputfile;
	if ($logo_length != $sizelogobin - 512) {
		print colored ("Warning: unexpected logo image file size! Trying to unpack it anyway...", 'yellow') . "\n";
	}

	# chop the header and any eventual garbage found at the EOF
	# (take only the important logo part which contains packed rgb565 images)
	my $logo = substr($logobin, 512, $logo_length);

	# check if logo length is really consistent
	if ( length ($logo) != $logo_length ) {
		die colored ("\nError: no way, the logo image file seems to be corrupted", 'red') . "\n";
	}

	if (-e "$ARGV[0]-unpacked") {
		rmtree "$ARGV[0]-unpacked";
		print "\nRemoved old unpacked logo directory '$ARGV[0]-unpacked'\n";
	}

	mkdir "$ARGV[0]-unpacked" or die;
	chdir "$ARGV[0]-unpacked" or die;
	print "Extracting raw images to directory '$ARGV[0]-unpacked'\n";

	# get the number of packed rgb565 images
	my $num_blocks = unpack('V', $logo);

	if ( ! $num_blocks ) {
		die "\nNo zlib packed rgb565 images were found inside logo file." . 
		    "\nRecheck script usage and try to use -force_logo_res switch.\n" unless ($switch eq "force_logo_res");

		# if no compressed files are found, try to unpack logo based on specified image resolution
		my $image_file_size = ($ARGV[2] * $ARGV[3] * 2);
		$num_blocks = int ($logo_length / $image_file_size);

		print "\nNumber of uncompressed images found (based on specified resolution): $num_blocks\n";
		
		for my $i (0 .. $num_blocks - 1) {
			my $filename = sprintf ("%s-img[%02d]", $ARGV[0], $i);

			open (RGB565FILE, ">$filename.rgb565");
			binmode (RGB565FILE);
			print RGB565FILE substr($logo, $i * $image_file_size, $image_file_size) or die;
			close (RGB565FILE);
			
			if ( $ImageMagick_installed ) {
				# convert rgb565 into png
				rgb565_to_png($filename, $ARGV[2], $ARGV[3]);

				print "Image #$i written to '$filename.png'\n";
			} else {
				print "Image #$i written to '$filename.rgb565'\n";
			}
		}
	} else {
		my $j = 0;
		my (@raw_addr, @zlib_raw) = ();
		print "\nNumber of raw images found: $num_blocks\n";
		# get the starting address of each rgb565 image
		for my $i (0 .. $num_blocks - 1) {
			$raw_addr[$i] = unpack('L', substr($logo, 8+$i*4, 4));
		}
		# extract rgb565 images (uncompress zlib rfc1950)
		for my $i (0 .. $num_blocks - 1) {
			if ($i < $num_blocks-1) {
				$zlib_raw[$i] = substr($logo, $raw_addr[$i], $raw_addr[$i+1]-$raw_addr[$i]);
			} else {
				$zlib_raw[$i] = substr($logo, $raw_addr[$i]);
			}
			my $filename = sprintf ("%s-img[%02d]", $ARGV[0], $i);

			open (RGB565FILE, ">$filename.rgb565");
			binmode (RGB565FILE);
			print RGB565FILE uncompress($zlib_raw[$i]) or die;
			close (RGB565FILE);

			# calculate image resolution
			my $raw_num_pixels = length (uncompress($zlib_raw[$i])) / 2;
			while ( $j <= $#resolution ) {
				last if ( $raw_num_pixels == ($resolution[$j][0] * $resolution[$j][1]) );
				$j++;
			}
			if ( $j <= $#resolution ) {
				if ( $ImageMagick_installed ) {
					# convert rgb565 into png
					rgb565_to_png($filename, $resolution[$j][0], $resolution[$j][1]);
					
					print "Image #$i written to '$filename.png'\n";
				} else {
					print "Image #$i written to '$filename.rgb565'\n";
				}
				print "  Resolution (width x height): $resolution[$j][0] x $resolution[$j][1] $resolution[$j][2]\n";
			} else {
				print "Image #$i written to '$filename.rgb565'\n";
				print "  Resolution: unknown\n";
			}
			$j = 0;
		}
	}

	print "\nSuccessfully extracted all images.\n";
}

sub rgb565_to_png {
	my ($filename, $img_width, $img_heigth) = @_;
	my ($raw_data, $data, $encoded);
	my $img_resolution = $img_width . "x" . $img_heigth;
	
	# convert rgb565 into raw rgb (rgb888)
	open (RGB565FILE, "$filename.rgb565") or die colored ("Error: could not open image '$filename.rgb565'", 'red') . "\n";
	binmode (RGB565FILE);
	while (read (RGB565FILE, $data, 2) != 0) {
		$encoded = unpack('S', $data);
		$raw_data .= pack('C C C', (($encoded >> 11) & 0x1F) * 255 / 31, (($encoded >> 5) & 0x3F) * 255 / 63, ($encoded & 0x1F) * 255 / 31);
	}
	close (RGB565FILE);

	open (RAWFILE, ">$filename.raw");
	binmode (RAWFILE);
	print RAWFILE $raw_data or die;
	close (RAWFILE);

	# convert raw rgb (rgb888) into png
	system ("convert -depth 8 -size $img_resolution rgb:$filename.raw $filename.png");

	# cleanup
	if (-e "$filename.png") {
		system ("rm $filename.rgb565 | rm $filename.raw");
	}
}
