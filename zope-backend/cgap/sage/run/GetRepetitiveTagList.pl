#!/usr/local/bin/perl

######################################################################
# GetRepetitiveTagList.pl
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
##   $format,
## ) = @ARGV;

my $query = new CGI;
my $format       = $query->param("FORMAT");

print "Content-type: text/plain\n\n";

Scan ($format);
print GetRepetitiveTagList_1 ($format);
