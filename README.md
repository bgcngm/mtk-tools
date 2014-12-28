# MTK-Tools by Bruno Martins
## MTK unpack and repack scripts

If you are looking for a way to easily unpack / repack boot.img, recovery.img or logo.bin from your MediaTek device, don't look any further. Here you can find my own Perl scripts.

Scripts were first based on the ones available on [Android-DLS WiKi](http://android-dls.com/wiki/index.php?title=HOWTO:_Unpack%2C_Edit%2C_and_Re-Pack_Boot_Images), but are now highly modified in order to work with specific MTK boot and recovery images. The scripts fully work with every image from all known MediaTek SoC:
- MT6516
- MT65x3 (MT6513 and MT6573)
- MT65x5 (MT6515 and MT6575)
- MT6577
- MT65x2 (MT6572, MT6582 and MT6592)
- MT6589
- MT83xx (MT8377 and MT8389)
- MT6595

#### Unpack script usage:

	Usage: unpack-MTK.pl <infile> [COMMAND ...]
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

- for the new platforms requirements, the script will print now on terminal the complete info about unpacked image, like this:
```
Valid Android signature found...

Input file information:

 Base: 0x10000000
 Kernel size: 4296704 bytes / load address: 0x10008000
 Kernel Offset: 0x00008000
 Ramdisk size: 609570 bytes / load address: 0x11000000
 Ramdisk Offset: 0x01000000
 Second stage size: 0 bytes / load address: 0x10f00000
 Second Offset: 0x00f00000
 Tags Offset: 0x00000100
 Page size: 2048 bytes
 ASCIIZ product name: ''
 Command line: (none)

Extra Arguments written to 'boot.img-Args.txt'
Kernel written to 'boot.img-kernel.img'
Removed old ramdisk directory 'boot.img-ramdisk'
Ramdisk size: 2132 blocks
Extracted ramdisk contents to directory 'boot.img-ramdisk'
```

#### Repack script usage:

	Usage: repack-MTK.pl COMMAND [...]
	
	COMMANDs are:
	
	  -boot <kernel> <ramdisk-directory> <outfile>
	    Repacks boot image
	
	  -recovery <kernel> <ramdisk-directory> <outfile>
	    Repacks recovery image
	
	  -logo [--no_compression] <logo-directory> <outfile>
	    Repacks logo image

#### Info script usage:

	Usage: info-MTK.pl <infile>
	  Checks boot and recovery image

- for a convenient way to check images info without unpacking. The result will be like this:
```
 Valid Android signature found...

 Android Boot Image Info Utility
 originally developed by osm0sis
 improved and corrected by carliv
 Printing information for "boot.img"

 Header:
  magic            : ANDROID!
  kernel_size      : 4296704  	  (00419000)
  kernel_addr      : 0x10008000

  ramdisk_size     : 609570  	  (00094d22)
  ramdisk_addr     : 0x11000000
  second_addr      : 0x10f00000

  tags_addr        : 0x10000100
  page_size        : 2048  	  (00000800)
  id               : 629841972212b1857149e489c1d26f1ca7338c55

 Other:
  magic offset     : 0x00000000
  base address     : 0x10000000

  kernel offset    : 0x00008000
  ramdisk offset   : 0x01000000
  second offset    : 0x00f00000
  tags offset      : 0x00000100

Successfully printed image informations.
```


#### Credits:

- **Android-DLS** for the initial scripts
- **starix** (from forum.china-iphone.ru) for the decryption of logo.bin files structure
- **osm0sis** for initial bootimage info script
- **carliv** for new platform support and new binaries

#### Support page:

Visit the [support page](http://forum.xda-developers.com/showthread.php?t=1587411) for any questions or comments. Please don't forget to hit "Thanks" button.

#### Copyright:

Copyright (C) 2012 Bruno Martins (bgcngm@XDA)

You may not distribute nor sell this software or parts of it in Source, Object nor in any other form without explicit permission obtained from the original author.
