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
use Cache;

## print "Content-type: text/plain\n\n";

my $cache = new Cache(CACHE_ROOT, GXS_CACHE_PREFIX);

my ($GXS_cache_id, $Filename) = $cache->MakeCacheFile();
if ($GXS_cache_id != $CACHE_FAIL) {
  open(OUT, ">>$Filename") or die "Can not open file $Filename";
  close OUT;
  chmod 0666, $Filename;
  print $GXS_cache_id;
}
else{
  print "Query Failed";
}
