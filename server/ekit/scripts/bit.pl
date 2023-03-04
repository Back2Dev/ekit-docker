#!/usr/bin/perl
my $magickdir = "/home/triton/.magick";
    mkdir $magickdir if (!-d $magickdir );
    if (!-f "$magickdir/type.xml") {
        my $command = qq{perl scripts/im.font.gen.pl >$magickdir/type.xml};
        system($command) == 0 or die "Unable to set up font catalogue : $command failed: $?";
    }

