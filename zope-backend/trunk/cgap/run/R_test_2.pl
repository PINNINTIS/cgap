#!/usr/local/bin/perl

#############################################################################
# SearchAbnorm.pl
#

use strict;
use CGI;

use Scan;

system( "/usr/local/bin/R --slave --no-save <  /share/content/CGAP/data/cache/SAGEGXS.4589.R > /share/content/CGAP/run/trash 2>&1" );

print "8888\n";


