#!/usr/local/bin/perl
 
######################################################################
# GetDKFromCache.pl
#
######################################################################
 
use strict;
use CGI;
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
 
use DKView;
 
my $query  = new CGI;
 
my $base      = $query->param("BASE");
my $cache_id  = $query->param("CACHE");
my $chr  = $query->param("CHR");
 
print "Content-type: image/gif\n\n";
## print "Content-type: text/plain\n\n";
## $cache_id = 304;
## $chr = 14;
 
print GetDKFromCache_1 (
    $base,
    $cache_id,
    $chr
);
 
