#!/usr/local/bin/perl

#############################################################################
# GetDKMicrobeByTags.pl
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
 
my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $tags      = $query->param("TAGS");
 
print "Content-type: text/plain\n\n";
 
Scan($base, $page, $tags);
if( $tags eq "" ) {
  print "Please enter tags";
  return;
}
print GetDKMicrobeByTags_1($base, $page, $tags);
