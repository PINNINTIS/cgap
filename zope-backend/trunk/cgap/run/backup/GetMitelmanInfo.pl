#!/usr/local/bin/perl

#############################################################################
# GetMitelmanTotal.pl
#

use strict;
use CGI;
use Scan;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CytSearchServer;
my $query     = new CGI;
my $what       = $query->param("WHAT");

print "Content-type: text/plain\n\n";

Scan($what);        
print GetMitelmanTotal_1($what);        
