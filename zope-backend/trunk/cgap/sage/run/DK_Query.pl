#!/usr/local/bin/perl

#############################################################################
# DK_Query.pl
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
my $libname         = $query->param("LIBNAME");
 
print "Content-type: text/plain\n\n";
 
Scan($base, $org, $libname);
print DK_Query_1($base, $org, $libname);
