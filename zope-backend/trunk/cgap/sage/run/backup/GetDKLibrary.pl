#!/usr/local/bin/perl

#############################################################################
# GetDKLibrary.pl
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
 
print "Content-type: text/plain\n\n";

print GetDKLibrary_1($base);
