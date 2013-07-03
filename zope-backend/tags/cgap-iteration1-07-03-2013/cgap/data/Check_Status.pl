#!/usr/local/bin/perl

######################################################################
# GetCacheId.pl
#
######################################################################

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPConfig;
use DBI;
use Cache;
use Scan;

## print "Content-type: text/plain\n\n";

my $CACHE_FAIL = 0;

my $file = CACHE_ROOT . GXS_CACHE_PREFIX . ".txt";

if (not (-e $file)) {
  print "<center><b>Error: Cache flag file is missing, please contact help desk. Sorry for inconvenient</b></center>";
  exit();
}

my ($sec, $min, $hr, $mday, $mon, $year, $wday, $yday, $isdst) =
      localtime(time);
my $t = (stat "$file")[9];
my ($f_sec, $f_min, $f_hr, $f_mday, $f_mon, $f_year, $f_wday, $f_yday, $f_isdst) = localtime($t);
 
my $flag;
if( $year > $f_year ) {
  print "<center><b>Error: Database is busy, please come back later and then try to sibmit your request again. Sorry for inconvenient</b></center>";
}
elsif( $yday > $f_yday ) {
  print "<center><b>Error: Database is busy, please come back later and then try to sibmit your request again. Sorry for inconvenient</b></center>";
}
elsif( $hr > $f_hr + 1 ) {
  print "<center><b>Error: Database is busy, please come back later and then try to sibmit your request again. Sorry for inconvenient</b></center>";
}
else {
  open(IN, "$file") or die "<center><b>Error: Cannot open file $file, please contact help desk. Sorry for inconvenient</b></center>";
  while(<IN>) {
    my $cache_id = $_;
    my $filename = CACHE_ROOT . "GXS" . "." . $cache_id;
    if ( -e $filename ) {
      my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
                      $atime, $mtime, $ctime, $blksize, $blocks)
                                           = stat ($filename);
      if( $size <= 100 ) {
        print "<center><b>Error: Database is busy, please come back later and then try to sibmit your request again. Sorry for inconvenient</b></center>";
      }
    }
  }
  close IN;
}
