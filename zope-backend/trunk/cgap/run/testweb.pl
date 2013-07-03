#!/usr/local/bin/perl

#############################################################################
# GetGeneByNumber.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

print "Content-type: text/plain\n\n";

print "OK\n";

