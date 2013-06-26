#!/usr/local/bin/perl

######################################################################
# GetTagDistOfLib
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;

## my (
##   $sage_library_id
## ) = @ARGV;

my $query      = new CGI;
my $sage_library_id = $query->param("LID");
my $org             = $query->param("ORG");
my $method          = $query->param("METHOD");

print "Content-type: text/plain\n\n";

print GetTagDistOfLib_1 ($sage_library_id, $org, $method);
