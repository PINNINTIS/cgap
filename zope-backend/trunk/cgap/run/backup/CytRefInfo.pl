#!/usr/local/bin/perl

#############################################################################
# CytRefInfo.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CytSearchServer;
use Scan;

my $query     = new CGI;
my $ref  = $query->param("REF");

print "Content-type: text/plain\n\n";

Scan($ref);
print CytRefInfo_1($ref);

## exit(GetStatus());
