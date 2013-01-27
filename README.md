# MTK-Tools by Bruno Martins
## MT65xx unpack and repack scripts

If you are looking for a way to easily unpack / repack boot.img, recovery.img or logo.bin from your MediaTek device, don't look any further. Here you can find my own Perl scripts.

Scripts were first based on the ones available on [Android-DLS WiKi](http://android-dls.com/wiki/index.php?title=HOWTO:_Unpack%2C_Edit%2C_and_Re-Pack_Boot_Images), but are now highly modified in order to work with specific MTK boot and recovery images. Currently, the scripts fully work with any MT6516, MT6513 or MT6573 images. It is also confirmed to be working with new MT6575 (and even MT6577) images.

#### Unpack script usage:

	Usage: unpack-MT65xx.pl <infile> [COMMAND ...]
	  Unpacks boot, recovery or logo image
	
	Optional COMMANDs are:
	
	  -kernel_only
	    Extract kernel only from boot or recovery image
	
	  -ramdisk_only
	    Extract ramdisk only from boot or recovery image
	
	  -force_logo_res <width> <height>
	    Forces logo image file to be unpacked by specifying image resolution,
	    which must be entered in pixels
	     (only useful when no zlib compressed images are found)
	
	  -invert_logo_res
	    Invert image resolution (width <-> height)
	     (may be useful when extracted images appear to be broken)

#### Repack script usage:

	Usage: repack-MT65xx.pl COMMAND [...]
	
	COMMANDs are:
	
	  -boot <kernel> <ramdisk-directory> <outfile>
	    Repacks boot image
	
	  -recovery <kernel> <ramdisk-directory> <outfile>
	    Repacks recovery image
	
	  -logo [--no_compression] <logo-directory> <outfile>
	    Repacks logo image

#### Credits:

- **Android-DLS** for the initial scripts
- **starix** (from forum.china-iphone.ru) for the decryption of logo.bin files structure

#### Support page:

Visit the [support page](http://forum.xda-developers.com/showthread.php?t=1587411) for any questions or comments. Please don't forget to hit "Thanks" button.
