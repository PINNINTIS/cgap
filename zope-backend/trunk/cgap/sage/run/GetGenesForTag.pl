#!/usr/local/bin/perl

######################################################################
# GetGenesForTag.pl
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
##   $base,
##   $format,
##   $tag,
##   $details
## ) = @ARGV;

my $query       = new CGI;
my $base        = $query->param("BASE");
my $format      = $query->param("FORMAT");
my $tag     = $query->param("TAG");
my $details = $query->param("DETAILS");
my $org     = $query->param("ORG");
my $method  = $query->param("METHOD");

print "Content-type: text/plain\n\n";

Scan ($base, $org, $method, $format, $tag, $details);

print GetGenesForTag_1 ($base, $org, $method, $format, 
                                              $tag, $details);



