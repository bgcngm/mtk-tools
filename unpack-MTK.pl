#!/usr/bin/perl

#
# Initial script from Android-DLS WiKi
#
# Change history:
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
#   - added support for new platforms - MT6595 (thanks to carliv@XDA) (29-12-2014)
#   - code cleanup and revised information output for boot and recovery images (29-12-2014)
#   - make scripts more future-proof by supporting even more args (30-12-2014)
#   - added new cmdline option for debugging purposes (06-01-2015)
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
use Text::Wrap;

my $version = "MTK-Tools by Bruno Martins\nMTK unpack script (last update: 06-01-2015)\n";
my $usageMain = "unpack-MTK.pl <infile> [COMMAND ...]\n  Unpacks MediaTek boot, recovery or logo images\n\n";
my $usageBootOpts =  "Optional COMMANDs for boot or recovery images are:\n\n  -info_only\n    Display file information only\n     (useful to check image information without unpacking)\n\n  -kernel_only [--debug]\n    Extract kernel only\n\n  -ramdisk_only [--debug]\n    Extract ramdisk only\n\n" . wrap("    ","     ","(optional argument '--debug' can additionally be used to provide useful information for debugging purposes, even while unpacking both kernel and ramdisk)") . "\n\n";
my $usageLogoOpts =  "Optional COMMANDs for logo images are:\n\n  -force_logo_res <width> <height>\n" . wrap("    ","     ","Forces file to be unpacked by specifying image resolution (in pixels)\n(only useful when no zlib compressed images are found)") . "\n\n  -invert_logo_res\n" . wrap("    ","     ","Invert image resolution (width <-> height)\n(may be useful when extracted images appear to be broken)") ."\n\n";
my $usage = $usageMain . $usageBootOpts . $usageLogoOpts;

print colored ("$version", 'bold blue') . "\n";
die "Usage: $usage" unless $ARGV[0];

if ($ARGV[1]) {
	if ($ARGV[1] eq "-info_only" || $ARGV[1] eq "-invert_logo_res" || $ARGV[1] eq "--debug") {
		die "Usage: $usage" unless !$ARGV[2];
	} elsif ($ARGV[1] eq "-kernel_only" || $ARGV[1] eq "-ramdisk_only") {
		die "Usage: $usage" unless (!$ARGV[2] || $ARGV[2] eq "--debug" && !$ARGV[3]);
	} elsif ($ARGV[1] eq "-force_logo_res") {
		die "Usage: $usage" unless (looks_like_number($ARGV[2]) && looks_like_number($ARGV[3]) && !$ARGV[4]);
	} else {
		die "Usage: $usage";
	}
}

my $inputfile = $ARGV[0];
my $inputFilename = fileparse($inputfile);

open (INPUTFILE, "$inputfile")
	or die_msg("couldn't open the specified file '$inputfile'!");
my $input;
while (<INPUTFILE>) {
	$input .= $_;
}
close (INPUTFILE);

if ((substr($input, 0, 4) eq "\x88\x16\x88\x58") & (substr($input, 8, 4) eq "LOGO")) {
	# if the input file contains the logo signature, try to unpack it
	print "Valid logo signature found...\n";
	if ($ARGV[1]) {
		die_msg("argument '$ARGV[1]' can't be used with logo images!")
			unless ($ARGV[1] eq "-force_logo_res" || $ARGV[1] eq "-invert_logo_res");
		$ARGV[1] =~ s/-//;
		unpack_logo($input, $ARGV[1]);
	} else {
		unpack_logo($input, "none");
	}
} elsif (substr($input, 0, 8) eq "ANDROID!") {
	# else, if a valid Android signature is found, try to unpack boot or recovery image
	print "Valid Android signature found...\n";
	if ($ARGV[1]) {
		die_msg("argument '$ARGV[1]' can't be used with boot or recovery images!")
			unless ($ARGV[1] eq "-info_only" || $ARGV[1] eq "-kernel_only" || $ARGV[1] eq "-ramdisk_only" ||
				$ARGV[1] eq "--debug");
		if ($ARGV[1] eq "--debug") {
			unpack_boot($input, "kernel and ramdisk", $ARGV[1]);
		} else {
			$ARGV[1] =~ s/-//;
			$ARGV[1] =~ s/_only//;
			unpack_boot($input, $ARGV[1], $ARGV[2] ? $ARGV[2] : "--normal");
		}
	} else {
		unpack_boot($input, "kernel and ramdisk", "--normal");
	}
} else {
	die_msg("the input file does not appear to be supported or valid!");
}

sub unpack_boot {
	my ($bootimg, $extract, $mode) = @_;
	my ($bootMagic, $kernelSize, $kernelLoadAddr, $ram1Size, $ram1LoadAddr, $ram2Size, $ram2LoadAddr, $tagsAddr, $pageSize, $unused1, $unused2, $bootName, $cmdLine, $id) = unpack('a8 L L L L L L L L L L a16 a512 a20', $bootimg);
	my $magicAddr = 0x00000000;
	my $baseAddr = $kernelLoadAddr - 0x00008000;
	my $kernelOffset = $kernelLoadAddr - $baseAddr;
	my $ram1Offset = $ram1LoadAddr - $baseAddr;
	my $ram2Offset = $ram2LoadAddr - $baseAddr;
	my $tagsOffset = $tagsAddr - $baseAddr;
	my $debug_mode = ($mode =~ /debug/ ? 1 : 0);
	my $unpack_sucess = 0;

	# remove trailing zeros from board and cmdline
	$bootName =~ s/\x00+$//;
	$cmdLine =~ s/\x00+$//;

	# print input file information (only in normal mode)
	if (!$debug_mode) {
		print colored ("\nInput file information:\n", 'cyan') . "\n";
		print colored (" Header:\n", 'cyan') . "\n";
		printf ("  Boot magic:\t\t\t%s\n", $bootMagic);
		printf ("  Kernel size (bytes):\t\t%d\t\t(0x%.8x)\n", $kernelSize, $kernelSize);
		printf ("  Kernel load address:\t\t0x%.8x\n\n", $kernelLoadAddr);
		printf ("  Ramdisk size (bytes):\t\t%d\t\t(0x%.8x)\n", $ram1Size, $ram1Size);
		printf ("  Ramdisk load address:\t\t0x%.8x\n", $ram1LoadAddr);
		printf ("  Second stage size (bytes):\t%d\t\t(0x%.8x)\n", $ram2Size, $ram2Size);
		printf ("  Second stage load address:\t0x%.8x\n\n", $ram2LoadAddr);
		printf ("  Tags address:\t\t\t0x%.8x\n", $tagsAddr);
		printf ("  Page size (bytes):\t\t%d\t\t(0x%.8x)\n", $pageSize, $pageSize);
		printf ("  ASCIIZ product name:\t\t'%s'\n", $bootName);
		printf ("  Command line:\t\t\t'%s'\n", $cmdLine);
		printf ("  ID:\t\t\t\t%s\n\n", unpack('H*', $id));
		print colored (" Other:\n", 'cyan') . "\n";
		printf ("  Boot magic offset:\t\t0x%.8x\n", $magicAddr);
		printf ("  Base address:\t\t\t0x%.8x\n\n", $baseAddr);
		printf ("  Kernel offset:\t\t0x%.8x\n", $kernelOffset);
		printf ("  Ramdisk offset:\t\t0x%.8x\n", $ram1Offset);
		printf ("  Second stage offset:\t\t0x%.8x\n", $ram2Offset);
		printf ("  Tags offset:\t\t\t0x%.8x\n", $tagsOffset);
	}

	if ($extract eq "info") {
		die colored ("Successfully displayed input file information.", 'green') . "\n";
	}

	# create file containing extra arguments for further repacking
	open (ARGSFILE, ">$inputFilename-args.txt")
		or die_msg("couldn't create file '$inputFilename-args.txt'!");
	printf ARGSFILE ("--base %#.8x\n--pagesize %d\n--kernel_offset %#.8x\n--ramdisk_offset %#.8x\n--second_offset %#.8x\n--tags_offset %#.8x%s%s", $baseAddr, $pageSize, $kernelOffset, $ram1Offset, $ram2Offset, $tagsOffset, $bootName eq "" ? "" : "\n--board $bootName", $cmdLine eq "" ? "" : "\n--cmdline $cmdLine") or die;
	close (ARGSFILE);
	print "\nExtra arguments written to '$inputFilename-args.txt'\n";

	if ($extract =~ /kernel/) {
		my $kernel = substr($bootimg, $pageSize, $kernelSize);

		open (KERNELFILE, ">$inputFilename-kernel.img")
			or die_msg("couldn't create file '$inputFilename-kernel.img'!");
		binmode (KERNELFILE);
		print KERNELFILE $kernel or die;
		close (KERNELFILE);

		print "Kernel written to '$inputFilename-kernel.img'\n";
		$unpack_sucess = 1;
	}

	if ($extract =~ /ramdisk/) {
		my $kernelAddr = $pageSize;
		my $kernelSizeInPages = int(($kernelSize + $pageSize - 1) / $pageSize);

		my $ram1Addr = (1 + $kernelSizeInPages) * $pageSize;
		my $ram1 = substr($bootimg, $ram1Addr, $ram1Size);

		# chop ramdisk header
		$ram1 = substr($ram1, 512);

		if (substr($ram1, 0, 2) ne "\x1F\x8B") {
			die_msg("the specified boot image does not appear to contain a valid gzip file!");
		}

		open (RAMDISKFILE, ">$inputFilename-ramdisk.cpio.gz")
			or die_msg("couldn't create file '$inputFilename-ramdisk.cpio.gz'!");
		binmode (RAMDISKFILE);
		print RAMDISKFILE $ram1 or die;
		close (RAMDISKFILE);

		if (-e "$inputFilename-ramdisk") {
			rmtree "$inputFilename-ramdisk";
			print "Removed old ramdisk directory '$inputFilename-ramdisk'\n";
		}

		mkdir "$inputFilename-ramdisk" or die;
		chdir "$inputFilename-ramdisk" or die;
		foreach my $tool ("gzip", "cpio") {
			die_msg("'$tool' binary not found! Double check your environment setup.")
				if system ("command -v $tool >/dev/null 2>&1");
		}
		if ($debug_mode) {
			print colored ("\nRamdisk unpack command:", 'yellow') . "\n";
			print "'gzip -d -c ../$inputFilename-ramdisk.cpio.gz | cpio -i'\n\n";
		}
		print "Ramdisk size: ";
		system ("gzip -d -c ../$inputFilename-ramdisk.cpio.gz | cpio -i");
		system ("rm ../$inputFilename-ramdisk.cpio.gz") unless ($debug_mode);

		print "Extracted ramdisk contents to directory '$inputFilename-ramdisk'\n";
		$unpack_sucess = 1;
	}

	if ($unpack_sucess == 1) {
		print colored ("\nSuccessfully unpacked $extract.", 'green') . "\n";
	}
}

sub unpack_logo {
	my ($logobin, $switch) = @_;
	my @resolution;

	# parse logo_res.txt file if it exists
	if (-e "$Bin/logo_res.txt") {
		open (LOGO_RESFILE, "$Bin/logo_res.txt")
			or die_msg("couldn't open file '$Bin/logo_res.txt'!");
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
	if (length($logo) != $logo_length) {
		die_msg("the specified logo image file seems to be corrupted!");
	}

	if (-e "$inputFilename-unpacked") {
		rmtree "$inputFilename-unpacked";
		print "\nRemoved old unpacked logo directory '$inputFilename-unpacked'";
	}

	mkdir "$inputFilename-unpacked" or die;
	chdir "$inputFilename-unpacked" or die;
	print "\nExtracting images to directory '$inputFilename-unpacked'\n";

	# get the number of packed rgb565 images
	my $num_blocks = unpack('V', $logo);

	if (!$num_blocks) {
		die_msg("no zlib packed rgb565 images were found inside logo file!" . 
			"\nDouble check script usage and try using '-force_logo_res' argument.") unless ($switch eq "force_logo_res");

		# if no compressed files are found, try to unpack logo based on specified image resolution
		my $image_file_size = ($ARGV[2] * $ARGV[3] * 2);
		$num_blocks = int ($logo_length / $image_file_size);

		print "\nNumber of uncompressed images found (based on specified resolution): $num_blocks\n";
		
		for my $i (0 .. $num_blocks - 1) {
			my $filename = sprintf ("%s-img[%02d]", $inputFilename, $i);

			open (RGB565FILE, ">$filename.rgb565")
				or die_msg("couldn't create image file '$filename.rgb565'!");
			binmode (RGB565FILE);
			print RGB565FILE substr($logo, $i * $image_file_size, $image_file_size) or die;
			close (RGB565FILE);
			
			if ($ImageMagick_installed) {
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
		print "\nNumber of images found: $num_blocks\n";
		# get the starting address of each rgb565 image
		for my $i (0 .. $num_blocks - 1) {
			$raw_addr[$i] = unpack('L', substr($logo, 8+$i*4, 4));
		}
		# extract rgb565 images (uncompress zlib rfc1950)
		for my $i (0 .. $num_blocks - 1) {
			if ($i < $num_blocks - 1) {
				$zlib_raw[$i] = substr($logo, $raw_addr[$i], $raw_addr[$i+1]-$raw_addr[$i]);
			} else {
				$zlib_raw[$i] = substr($logo, $raw_addr[$i]);
			}
			my $filename = sprintf ("%s-img[%02d]", $inputFilename, $i);

			open (RGB565FILE, ">$filename.rgb565")
				or die_msg("couldn't create image file '$filename.rgb565'!");
			binmode (RGB565FILE);
			print RGB565FILE uncompress($zlib_raw[$i]) or die;
			close (RGB565FILE);

			# calculate image resolution
			my $raw_num_pixels = length (uncompress($zlib_raw[$i])) / 2;
			while ($j <= $#resolution) {
				last if ($raw_num_pixels == ($resolution[$j][0] * $resolution[$j][1]));
				$j++;
			}
			if ($j <= $#resolution) {
				if ($ImageMagick_installed) {
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

	print colored ("\nSuccessfully extracted all images.", 'green') . "\n";
}

sub rgb565_to_png {
	my ($filename, $img_width, $img_heigth) = @_;
	my ($raw_data, $data, $encoded);
	my $img_resolution = $img_width . "x" . $img_heigth;
	
	# convert rgb565 into raw rgb (rgb888)
	open (RGB565FILE, "$filename.rgb565")
		or die_msg("couldn't open image file '$filename.rgb565'!");
	binmode (RGB565FILE);
	while (read (RGB565FILE, $data, 2) != 0) {
		$encoded = unpack('S', $data);
		$raw_data .= pack('C C C',
			(($encoded >> 11) & 0x1F) * 255 / 31,
			(($encoded >> 5) & 0x3F) * 255 / 63,
			($encoded & 0x1F) * 255 / 31);
	}
	close (RGB565FILE);

	open (RAWFILE, ">$filename.raw")
		or die_msg("couldn't create raw image file '$filename.raw'!");
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

sub die_msg {
	die colored ("\n" . wrap("","","Error: $_[0]"), 'red') . "\n";
}

