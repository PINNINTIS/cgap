#!/usr/local/bin/perl

############################################ 
## GetSVGMicroaarayFromCache.pl
############################################ 

use strict;
use CGI;
use Draw_SVG;
use Scan;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

my $query     = new CGI;
my $base      = $query->param("BASE");
my $path      = $query->param("PATH");

## print "Content-type: image/svg-xml\n\n";
## print "Content-type: text/plain\n\n";
print "Content-type: image/gif\n\n";

Scan($base, $path);
print GetSVGMicroarrayFromCache_1($base, $path);
