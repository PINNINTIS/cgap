#!/usr/local/bin/perl

#############################################################################
# DKDownload.pl
#
 
use strict;
use CGI;
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
use DKView;
 
my $query            = new CGI;
my $base             = $query->param("BASE");
my $org              = $query->param("ORG");
my $cache_id         = $query->param("CACHE_ID");
my $filename         = $query->param("FILENAME");
 
print "Content-type: text/plain\n\n";
 
print DKDownload_1($base, $cache_id);
