#!/usr/local/bin/perl

#############################################################################
# BuildLibPage.pl
#

use strict;
use CGI;
use Scan;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPLib;

##my ($base, $org, $lid) = @ARGV;

my $query  = new CGI;
my $base   = $query->param("BASE");
my $org    = $query->param("ORG");
my $lid    = $query->param("LID");

print "Content-type: text/plain\n\n";

Scan($base, $org, $lid);
print BuildLibPage_1($base, $org, $lid);
