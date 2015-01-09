#!/usr/bin/perl

#
# Initial script from Android-DLS WiKi
#
# Change history:
#   - modified to work with MT6516 boot and recovery images (17-03-2011)
#   - included support for MT65x3 and eliminated the need of header files (16-10-2011)
#   - added cygwin mkbootimg binary and propper fix (17-05-2012)
#   - included support for MT65xx logo images (31-07-2012)
#   - added colored screen output (04-01-2013)
#   - included support for logo images containing uncompressed raw files (06-01-2013)
#   - re-written check of needed binaries (13-01-2013)
#   - added rgb565 <=> png images conversion (27-01-2013)
#   - code cleanup and revised verbose output (16-10-2014)
#   - added support for new platforms - MT6595 (thanks to carliv@XDA) (29-12-2014)
#   - minor code cleanup (29-12-2014)
#   - make scripts more future-proof by supporting even more args (30-12-2014)
#   - continue repacking even if there's no extra args file (01-01-2015)
#   - more verbose output when repacking boot and recovery images (02-01-2015)
#   - added new cmdline option for debugging purposes (06-01-2015)
#

use v5.14;
use warnings;
use Cwd;
use Compress::Zlib;
use Term::ANSIColor;
use FindBin qw($Bin);
use File::Basename;
use Text::Wrap;

my $dir = getcwd;

my $version = "MTK-Tools by Bruno Martins\nMTK repack script (last update: 06-01-2015)\n";
my $usageMain = "repack-MTK.pl <COMMAND ...> <outfile>\n  Repacks MediaTek boot, recovery or logo images\n\n";
my $usageBootOpts =  "COMMANDs for boot or recovery images are:\n\n  -boot [--debug] <kernel> <ramdisk-directory>\n    Repacks boot image\n\n  -recovery [--debug] <kernel> <ramdisk-directory>\n    Repacks recovery image\n\n" . wrap("    ","     ","(optional argument '--debug' can additionally be used to provide useful information for debugging purposes, while repacking)") . "\n\n";
my $usageLogoOpts =  "COMMANDs for logo images are:\n\n  -logo [--no_compression] <logo-directory>\n    Repacks logo image\n\n" . wrap("    ","     ","(optional argument '--no_compression' can be used to repack logo images without compression)") . "\n\n";
my $usage = $usageMain . $usageBootOpts . $usageLogoOpts;

print colored ("$version", 'bold blue') . "\n";
die "Usage: $usage" unless $ARGV[0] && $ARGV[1] && $ARGV[2];

if ($ARGV[0] eq "-boot" || $ARGV[0] eq "-recovery") {
	if ($ARGV[1] eq "--debug") {
		die "Usage: $usage" unless $ARGV[3] && $ARGV[4] && !$ARGV[5];
	} else {
		die "Usage: $usage" unless $ARGV[3] && !$ARGV[4];
		splice (@ARGV, 1, 0, "--normal"); 
	}
	repack_boot();
} elsif ($ARGV[0] eq "-logo") {
	if ($ARGV[1] eq "--no_compression") {
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
	my ($type, $mode, $kernel, $ramdiskdir, $outfile) = @ARGV;
	$type =~ s/^-//;
	my $debug_mode = ($mode =~ /debug/ ? 1 : 0);
	$ramdiskdir =~ s/\/$//;
	my $ramdiskfile = "ramdisk-new.cpio.gz";
	my $signature = ($type eq "boot" ? "ROOTFS" : "RECOVERY");
	my %args = (base => "0x10000000", kernel_offset => "0x00008000", ramdisk_offset => "0x01000000", second_offset => "0x00f00000", tags_offset => "0x00000100", pagesize => 2048, board => "", cmdline => "");

	die_msg("kernel file '$kernel' not found!") unless (-e $kernel);
	chdir $ramdiskdir or die_msg("directory '$ramdiskdir' not found!");

	foreach my $tool ("find", "cpio", "gzip") {
		die_msg("'$tool' binary not found! Double check your environment setup.")
			if system ("command -v $tool >/dev/null 2>&1");
	}
	print "Repacking $type image...\n";
	if ($debug_mode) {
		print colored ("\nRamdisk repack command:", 'yellow') . "\n";
		print "'find . | cpio -o -H newc | gzip > $dir/$ramdiskfile'\n\n";
	}
	print "Ramdisk size: ";
	system ("find . | cpio -o -H newc | gzip > $dir/$ramdiskfile");

	chdir $dir or die "\n$ramdiskdir $!";;

	open (RAMDISKFILE, $ramdiskfile)
		or die_msg("couldn't open ramdisk file '$ramdiskfile'!");
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

	if ($debug_mode) {
		open (HEADERFILE, ">ramdisk-new.header")
			or die_msg("couldn't create MTK header file 'ramdisk-new.header'!");
		binmode (HEADERFILE);
		print HEADERFILE $header or die;
		close (HEADERFILE);
	} elsif (-e "ramdisk-new.header") {
		system ("rm ramdisk-new.header");
	}
	open (RAMDISKFILE, ">temp-$ramdiskfile")
		or die_msg("couldn't create repacked ramdisk file 'temp-$ramdiskfile'!");
	binmode (RAMDISKFILE);
	print RAMDISKFILE $newramdisk or die;
	close (RAMDISKFILE);
	
	# load extra args needed for creating the output file
	my $argsfile = $kernel;
	$argsfile =~ s/-kernel.img/-args.txt/;
	my @extrargs;
	if (-e $argsfile) {
		open(ARGSFILE, $argsfile)
			or die_msg("couldn't open extra args file '$argsfile'!");
		while (<ARGSFILE>) {
			if ($_ =~ /^\--(\w+) (.+)$/) {
				if (exists $args{$1}) {
					push (@extrargs, $_);
					$args{$1} = $2;
				}
			}
		}
		close (ARGSFILE);
		chomp (@extrargs);
	} else {
		print colored ("\nWarning: file containing extra arguments was not found! The $type image will be repacked using default base address, kernel and ramdisk offsets (as shown bellow).", 'yellow') . "\n";
	}

	# print build information (only in normal mode)
	if (!$debug_mode) {
		print colored ("\nBuild information:\n", 'cyan') . "\n";
		print colored (" Base address and offsets:\n", 'cyan') . "\n";
		printf ("  Base address:\t\t\t%s\n", $args{"base"});
		printf ("  Kernel offset:\t\t%s\n", $args{"kernel_offset"});
		printf ("  Ramdisk offset:\t\t%s\n", $args{"ramdisk_offset"});
		printf ("  Second stage offset:\t\t%s\n", $args{"second_offset"});
		printf ("  Tags offset:\t\t\t%s\n\n", $args{"tags_offset"});
		print colored (" Other:\n", 'cyan') . "\n";
		printf ("  Page size (bytes):\t\t%s\n", $args{"pagesize"});
		printf ("  ASCIIZ product name:\t\t'%s'\n", $args{"board"});
		printf ("  Command line:\t\t\t'%s'\n", $args{"cmdline"});
	}

	# create the output file
	my $tool = "mkbootimg" . (($^O eq "cygwin") ? ".exe" : (($^O eq "darwin") ? ".osx" : ""));
	die_msg("couldn't execute '$tool' binary!\nCheck if file exists or its permissions.")
		unless (-x "$Bin/$tool");
	if ($debug_mode) {
		print colored ("\nBuild $type image command:", 'yellow') . "\n";
		print "'$tool --kernel $kernel --ramdisk temp-$ramdiskfile @extrargs -o $outfile'\n";
	}
	system ("$Bin/$tool --kernel $kernel --ramdisk temp-$ramdiskfile @extrargs -o $outfile");

	# cleanup
	unlink ($ramdiskfile) or die $! unless ($debug_mode);
	system ("rm temp-$ramdiskfile");

	if (-e $outfile) {
		print colored ("\nSuccessfully repacked $type image into '$outfile'.", 'green') . "\n";
	}
}

sub repack_logo {
	my ($type, $logodir, $outfile) = @ARGV;
	my ($logobin, $logo_length);
	my (@raw_addr, @raw, @zlib_raw);
	$logodir =~ s/\/$//;

	my $compression = ($type eq "--no_compression" ? 0 : 1);
	my $filename = $logodir =~ s/-unpacked$//r;

	chdir $logodir or die_msg("directory '$logodir' not found!");

	my $i = 0;
	printf ("Repacking logo image%s...\n", $compression ? "" : " (without compression)" );
	for my $inputfile (glob "./$filename-img[*.*") {
		my $extension = (fileparse($inputfile, qr/\.[^.]*/))[2];
		$inputfile =~ s/^.\///;
		
		if ($extension eq ".png") {
			die_msg("couldn't find 'ImageMagick' tool! Please install it and try again.")
				if system ("command -v convert >/dev/null 2>&1");

			print "Converting and packing '$inputfile'\n";
			$raw[$i] = png_to_rgb565($inputfile);
		} elsif ($extension eq ".rgb565") {
			open (RGB565FILE, "$inputfile")
				or die_msg("couldn't open image file '$inputfile'!");
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
	die_msg("couldn't find any .png or .rgb565 file under the specified directory '$logodir'!")
		unless $i > 0;

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
	open (LOGOFILE, ">$outfile")
		or die_msg("couldn't create output file '$outfile'!");
	binmode (LOGOFILE);
	print LOGOFILE $logobin or die;
	close (LOGOFILE);

	if (-e $outfile) {
		print colored ("\nSuccessfully repacked logo image into '$outfile'.", 'green') . "\n";
	}
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
	open (RAWFILE, "$filename.raw")
		or die_msg("couldn't open temporary image file '$filename.raw'!");
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

sub die_msg {
	die colored ("\n" . wrap("","       ","Error: $_[0]"), 'red') . "\n";
}

