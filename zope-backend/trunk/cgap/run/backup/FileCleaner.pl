#!/usr/local/bin/perl

use strict;
use constant HOURS_TO_LIVE => 720;
use constant TIME_TO_LIVE  => HOURS_TO_LIVE * 60 * 60;

my %prefixes = (
  "Picked"              => "1",
  "Trace"               => "1",
  "library"             => "1",
  "everything_analyze"  => "1",
  "everything"          => "1"
);

my %PATHES = (
  "/cgap/schaefec/current/CGAP/data"         => "1",
  "/cgap/schaefec/current/CGAP/build"        => "1",
  "/cgap/schaefec/current/MGC/data"          => "1",
  "/cgap/schaefec/current/MGC/build"         => "1",
  "/cgap/schaefec/current/LL_AND_SP/build"   => "1"
);

my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
    $atime, $mtime, $ctime, $blksize, $blocks);

my $now = time();

for my $PATH( keys %PATHES ) {
  clean( $PATH );
}

sub clean {
  my ( $PATH ) =@_;
  opendir (DIR, $PATH) || die "can not open $PATH";  
  while( my $filename = readdir(DIR) ) {
    if( !($filename =~ /^\./) ) {
      if( $filename =~ /^[a-zA-Z_]+\./) {
        my ($prefix, $remaining) = split /\./, $filename;
        if (defined $prefixes{$prefix}){
          if( ( $prefix eq "Picked" and $filename =~/^Picked\.Clones/ ) or 
              ( $prefix eq "Trace" and $filename =~/^Trace\.Info/ ) or 
              ( $prefix eq "library" and $filename =~/^library\.report/ ) or 
              ( $filename =~/^everything_analyze\./ ) or 
              ( $filename =~ /^everything\./ ) ) { 
            $filename = $PATH . "/" . $filename;
            ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
                 $atime, $mtime, $ctime, $blksize, $blocks) = stat ($filename);
            my $tmp = TIME_TO_LIVE;
            if ($now - $mtime > TIME_TO_LIVE) {
              print "deleting file: $filename\n";
              unlink($filename);
            }
          }
        }
      }
    }
  }
  closedir DIR;
}
            ## if ($now - $atime > TIME_TO_LIVE) {
