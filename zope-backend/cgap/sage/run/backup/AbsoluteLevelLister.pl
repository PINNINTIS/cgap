#!/usr/local/bin/perl

######################################################################
# AbsoluteLevelLister.pl
#
# Given a SAGE library, list in order (from most highly expressed
# to least expressed) tags/genes

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
##   $sage_library_id,
##   $min,
##   $max
## ) = @ARGV;

my $query      = new CGI;
my $format     = $query->param("FORMAT");
my $sage_library_id = $query->param("LID");
my $min = $query->param("MIN");
my $max = $query->param("MAX");
my $org = $query->param("ORG");
my $method = $query->param("METHOD");

print "Content-type: text/plain\n\n";

print AbsoluteLevelLister_1 ($format, $sage_library_id,
    $min, $max, $org, $method);
