#!/usr/local/bin/perl

#############################################################################
# RefSearch.pl
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

my $op      = $query->param("op");
my $author  = $query->param("author");
my $journal  = $query->param("journal");
my $refno  = $query->param("refno");
my $year  = $query->param("year");
my $page  = $query->param("page");

print "Content-type: text/plain\n\n";

Scan($page, $author, $journal, $op, $refno, $year);
print RefSearch_1($page, $author, $journal, $op, $refno, $year);

exit(GetStatus());
