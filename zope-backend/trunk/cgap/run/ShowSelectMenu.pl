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
my $query       = new CGI;
my $table       = $query->param("TABLE");
my $head        = $query->param("HEAD");

print "Content-type: text/plain\n\n";

print "<h3>$head Menu</h3>";

Scan($table);        
print ShowSelectMenu_1($table);        
