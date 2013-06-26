#!/usr/local/bin/perl

#############################################################################
# SearchAbnorm.pl
#

use strict;
use CGI;

use Scan;

system( "/usr/local/bin/R --slave --no-save <  /share/content/CGAP/data/cache/SAGEGXS.455.R > /dev/null 2>&1" );

print "8888\n";


