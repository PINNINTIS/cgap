#!/usr/local/bin/perl

######################################################################
# GetTagsForAccession.pl
#


use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;

my $query       = new CGI;
my $base        = $query->param("BASE");
my $org         = $query->param("ORG");
my $method      = $query->param("METHOD");
my $format      = $query->param("FORMAT");
my $acc         = $query->param("ACC");

#my (
#   $base,
#   $org,
#   $method,
#   $format,
#   $acc
# ) = @ARGV;

print "Content-type: text/plain\n\n";

print GetTagsForAccession_1 ($base, $org, $method, $format, $acc);
