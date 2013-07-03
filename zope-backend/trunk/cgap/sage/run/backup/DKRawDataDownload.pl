#!/usr/local/bin/perl

#############################################################################
# DKRawDataDownload.pl
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
my $filename         = $query->param("FILENAME");
 
print "Content-type: text/plain\n\n";
 
print DKRawDataDownload_1($base, $filename);
