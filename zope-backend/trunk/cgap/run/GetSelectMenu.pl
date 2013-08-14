#!/usr/local/bin/perl

#############################################################################
# GetSelectMenu.pl
#

use strict;
use CGI;
use Scan;


BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CytSearchServer;
my $query     = new CGI;
my $table       = $query->param("TABLE");

$table       = cleanString($table);
#$table = $table."**";

print "Content-type: text/plain\n\n";

Scan($table);        
print GetSelectMenu_1($table);  
