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
use Scan;

## my (
##   $sage_library_id
## ) = @ARGV;

my $query      = new CGI;
my $sage_library_id = $query->param("LID");
$sage_library_id = cleanString($sage_library_id ); 
my $org             = $query->param("ORG");
$org             = cleanString($org); 
my $method          = $query->param("METHOD");
$method          = cleanString($method); 

print "Content-type: text/plain\n\n";

Scan ($sage_library_id, $org, $method);
print GetTagDistOfLib_1 ($sage_library_id, $org, $method);
