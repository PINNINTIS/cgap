#!/usr/local/bin/perl

######################################################################
# MEMatrix.pl
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
##   $org,
##   $method,
##   $format,
##   $tag,
##   $state
## ) = @ARGV;

my $query    = new CGI;
my $org      = $query->param("ORG");
my $method   = $query->param("METHOD");
my $format   = $query->param("FORMAT");
my $tag      = $query->param("TAG");
my $state    = $query->param("STATE");

print "Content-type: text/plain\n\n";

print MEMatrix_1 ($org, $method, $format, $tag, $state);

