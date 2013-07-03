#!/usr/local/bin/perl

######################################################################
# GetFreqsOfTagMatrix.pl
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
##   $tag,
##   $tiss,
##   $stage,
##   $libs,
##   $org,
##   $method,
##   $format
## ) = @ARGV;

my $query    = new CGI;
my $tag      = $query->param("TAG");
my $tiss     = $query->param("TISS");
my $stage    = $query->param("STAGE");
my $org      = $query->param("ORG");
my $method   = $query->param("METHOD");
my $format   = $query->param("FORMAT");

print "Content-type: text/plain\n\n";

Scan ($tag, $tiss, $stage, $org, $method, $format);
print GetFreqsOfTagMatrix_1 ($tag, $tiss, $stage, $org, $method, $format);

