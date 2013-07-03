#!/usr/local/bin/perl

######################################################################
# GetTagsForKey.pl
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
##   $keyword,
##   $details
## ) = @ARGV;

my $query       = new CGI;
my $base        = $query->param("BASE");
my $format      = $query->param("FORMAT");
my $keyword     = $query->param("KEYWORD");
my $details     = $query->param("DETAILS");
my $org         = $query->param("ORG");
my $method      = $query->param("METHOD");

print "Content-type: text/plain\n\n";

#my ($base, $format, $keyword, $details, $org, $method) = @ARGV;
print GetTagsForKey_1 ($base, $format, $keyword, $details, 
                                       $org, $method);

