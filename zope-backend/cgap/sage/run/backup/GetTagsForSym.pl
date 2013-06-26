#!/usr/local/bin/perl

######################################################################
# GetTagsForSym.pl
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
##   $format,
##   $term,
##   $details
## ) = @ARGV;

my $query       = new CGI;
my $base        = $query->param("BASE");
my $format      = $query->param("FORMAT");
my $term        = $query->param("TERM");
my $details     = $query->param("DETAILS");
my $org         = $query->param("ORG");
my $method      = $query->param("METHOD");

print "Content-type: text/plain\n\n";

#my ($base, $format, $term, $details, $org, $method) = @ARGV;
print GetTagsForSym_1 ($base, $format, $term, $details, 
                                       $org, $method);

