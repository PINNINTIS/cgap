#!/usr/local/bin/perl

#############################################################################
# HelpLists.pl
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

my $filename   = $query->param("FIELDNAME");
my $tablename  = $query->param("TABLENAME");

print "Content-type: text/plain\n\n";

Scan($filename, $tablename);
print HelpLists_1($filename, $tablename);

exit(GetStatus());
