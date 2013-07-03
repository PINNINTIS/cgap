#!/usr/local/bin/perl

######################################################################
# GetTissueList.pl
#


use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;
use Scan;

##my ($org, $method) = @ARGV;

my $query      = new CGI;
my $org        = $query->param("ORG");
my $method     = $query->param("METHOD");

print "Content-type: text/plain\n\n";

Scan ($org, $method);
print GetTissueList_1 ($org, $method);
