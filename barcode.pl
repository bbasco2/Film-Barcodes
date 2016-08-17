#!/usr/bin/perl
# Little program that creates barcode images out of a film
#  - Barcode gets processed and generated in a working folder specified by $BARCODE_PATH
#  - Uses ImageMagick + ffmpeg
#
# 2012 - bbasco2.deviantart.com
#
use 5.018;
use strict;
use warnings;

# Working directory where barcode will be processed and created
# - same location as the script
my $BARCODE_PATH = './barcode/';

# Error checking
{
	die <<"	USAGE" =~ s/^\t+//gmr if @ARGV != 2;
	Film barcode creator.
	Usage: $0 FILM_NAME BARCODE_PREFIX
	USAGE
	
	# temporary working folder for barcode processing
	$BARCODE_PATH =~ s|^(.*)[\/\\]?$|$1/|; # make sure the barcode path ends with '/'
	if ( !-d $BARCODE_PATH ) {
		mkdir $BARCODE_PATH or die "Barcode working directory could not be created at [$BARCODE_PATH]!";
	}
	
	# Check for required programs
	my $stat;
	
	# ffmpeg
	$stat = `ffmpeg -version 2>&1`;
	if ( $? ) {
		die <<"		ERROR" =~ s/^\t+//gmr;
		ffmpeg not found!
		
		$stat
		ERROR
	}
	
	# convert (ImageMagick)
	$stat = `convert --version 2>&1`;
	if ( $? ) {
		die <<"		ERROR" =~ s/^\t+//gmr;
		ImageMagick "convert" not found!
		
		$stat
		ERROR
	}
	
	# montage (ImageMagick)
	$stat = `montage --version 2>&1`;
	if ( $? ) {
		die <<"		ERROR" =~ s/^\t+//gmr;
		ImageMagick "montage" not found!
		
		$stat
		ERROR
	}
	
}

# Get the initial film screenshots with ffmepg
{
	my @sys_args = (
		'ffmpeg',
		"-i $ARGV[0]",
		'-loglevel error', # Shhh...no tears! Only errors now...
		'-r 2', # ~2 images per second
		'-f image2', # save to image file (vs video)
		'-qscale 1', # high quality
		'-vcodec png',
		"${BARCODE_PATH}movie-%06d.png",
		'2>&1',
	);
	
	my $stat = `"@sys_args"`;
	
	# something went wrong
	if ( $? ) {
		die <<"		ERROR" =~ s/^\t+//gmr;
		[@sys_args] failed:
		
		$stat
		ERROR
	}
	
	say "\n####################\n";
}

# Process each of the files with ImageMagick
{
	print "Resizing images  ";
	
	local $| = 1;
	my $x = "\b|";
	my %p = ("\b|"=>"\b/", "\b/"=>"\b-", "\b-"=>"\b\\", "\b\\"=>"\b|");
	my $i = 0;
	
	opendir ( my $DIR, $BARCODE_PATH ) or die "Could not read directory $BARCODE_PATH!\n$!\n$^E";
	while ( my $img = readdir($DIR) ) {
		next if     $img =~ /^\./;      # skip 'dot' files and directory listing.
		next unless $img =~ /^movie\-/; # skip images that are not original screenshots
		
		print $x;
		$x = $p{$x};
		
		my @sys_args = (
			'convert',
			"png:${BARCODE_PATH}$img",
			'-resize 1!', # 1 pixel wide (height is unchanged)
			# leave HUE unchanged, increase SATURATION (145) and BRIGHTNESS (110)
			'-set option:modulate:colorspace hsb -modulate 100,145,110',
			'-motion-blur 0x20+90', # slightly blur and smear the strip vertically to smooth out the colours
			"png:${BARCODE_PATH}bar-".(sprintf '%06d', $i).'.png',
		);
		
		my $stat = `"@sys_args"`;
		
		# something went wrong
		if ( $? ) {
			die <<"			ERROR" =~ s/^\t+//gmr;
			[@sys_args] failed:
			
			$stat
			ERROR
		}
		
		unlink $BARCODE_PATH.$img or die "Could not delete [${BARCODE_PATH}$img]:\n$!\n$^E";
		
		$i++;
	}
	print "\n";
	
	closedir $DIR;
	say "\n####################\n";
}

# Assemble the barcode with ImageMagick
{
	say "Building barcode.";
	
	my $prefix = $ARGV[1] // die "Barcode prefix not defined!";
	
	my @sys_args = (
		'montage',
		'-geometry +0+0', # Arrange the images side-by-side
		'-tile x1',       #  in numerical order
		"png:${BARCODE_PATH}bar*.png",
		"jpg:${BARCODE_PATH}${prefix}_barcode.jpg",
	);
	
	my $stat = `"@sys_args"`;
	
	# something went wrong
	if ( $? ) {
		die <<"		ERROR" =~ s/^\t+//gmr;
		[@sys_args] failed:
		
		$stat
		ERROR
	}
	
	say "\n####################\n";
}

# Final cleanup
{
	opendir ( my $DIR, $BARCODE_PATH ) or die "Could not read directory $BARCODE_PATH!\n$!\n$^E";
	while ( my $img = readdir($DIR) ) {
		next if $img =~ /^\./;     # skip 'dot' files and directory listing.
		next if $img =~ /barcode/; # skip the barcode we just created
		
		unlink $BARCODE_PATH.$img or die "Could not delete ${BARCODE_PATH}${img}]:\n$!\n$^E";
	}
	
	closedir $DIR;
	
	say "$ARGV[0] complete!";
	say "All done!";
}

1;