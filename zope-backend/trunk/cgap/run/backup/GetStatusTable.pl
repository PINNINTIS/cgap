#!/usr/local/bin/perl

#############################################################################
# GetStatusTable.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use RNAi;
use Scan;

my $query     = new CGI;
my $base      = $query->param("BASE");

##my ($base) = @ARGV;

print "Content-type: text/plain\n\n";
Scan($base);
print GetStatusTable_1($base);
