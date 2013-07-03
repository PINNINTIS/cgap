#!/usr/local/bin/perl

#############################################################################
# CytCaseInfo.pl
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

my $ref       = $query->param("REF");
my $case      = $query->param("CASE");

print "Content-type: text/plain\n\n";

Scan($ref, $case);
print CytCaseInfo_1($ref, $case);

exit(GetStatus());
