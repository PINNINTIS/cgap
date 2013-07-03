#!/usr/local/bin/perl

#############################################################################
# DKView.pl
#
 
use strict;
use CGI;
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
use GENOMICSDKViewBK;
use Scan;
 
my $query            = new CGI;
my $base             = $query->param("BASE");
my $org              = $query->param("ORG");
my $cache_id         = $query->param("CACHE_ID");
my $window_size      = $query->param("WINDOWSIZE");
my $filedata         = $query->param("filenameFILE");
 
print "Content-type: text/plain\n\n";
 
Scan($base, $org, $cache_id, $window_size, $filedata);
print DKView_1($base, $org, $cache_id, $window_size, $filedata);
