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
use DKView;
use Scan;
 
my $query            = new CGI;
my $base             = $query->param("BASE");
my $org              = $query->param("ORG");
my $cache_id         = $query->param("CACHE_ID");
my $window_size      = $query->param("WINDOWSIZE");
my $filename         = $query->param("FILENAME");
my $DEL_WIDTH        = $query->param("DELWIDTH");
my $DEL_THRESHHOLD   = $query->param("DELTHRESHHOLD");
my $AMP_WIDTH        = $query->param("AMPWIDTH");
my $AMP_THRESHHOLD   = $query->param("AMPTHRESHHOLD");
 
print "Content-type: text/plain\n\n";
 
Scan($base, $org, $cache_id, $window_size, $filename,
     $DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD);

print DKView_1($base, $org, $cache_id, $window_size, $filename,
               $DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD);
