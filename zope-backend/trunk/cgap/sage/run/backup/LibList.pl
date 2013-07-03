#!/usr/local/bin/perl

######################################################################
# List.pl
#
# List all SAGE libraries
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;

##my (
##  $sage_library_id
##) = @ARGV;
#my ( $org ) = @ARGV;

my $query      = new CGI;
my $org = $query->param("ORG");

print "Content-type: text/plain\n\n";

print LibList_1 ($org);
