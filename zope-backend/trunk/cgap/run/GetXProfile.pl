#!/usr/local/bin/perl

#############################################################################
# GetXProfile.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use GLServer;
use Scan;

my $query        = new CGI;
my $base         = $query->param("BASE");
my $org          = $query->param("ORG");
my $a_set        = $query->param("A_SET");
my $b_set        = $query->param("B_SET");
 
print "Content-type: text/plain\n\n";

Scan($base, $org, $a_set, $b_set);
print GetXProfile_1($base, $org, $a_set, $b_set);

