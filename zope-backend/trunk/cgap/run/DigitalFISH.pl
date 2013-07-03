#!/usr/local/bin/perl

#############################################################################
# DigitalFISH.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use DigitalFISH;

##my ($base, $org) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $org       = $query->param("ORG");

print "Content-type: text/plain\n\n";

print DigitalFISH_1($base, $org);
#print DigitalFISH_2($base, $org);
