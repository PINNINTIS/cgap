#!/usr/local/bin/perl

## Invoking through the Zope html form
##    (e.g. http://cgap-stage.nci.nih.gov/Maint/Act?CMD=ps)
##    will cause the cgi to run under user apache
## Invoking via cgapcgi redirect
##    (e.g. http://cgap-stage.nci.nih.gov/cgapcgi?SpyProcess.pl?CMD=ps)
##    will cause the cgi to run under user apache
## Invoking through Zope ZCGI
##    (e.g. http://cgap-stage.nci.nih.gov/Maint/cgi-bin/SpyProcess?CMD=ps)
##    will cause the cgi to run under user zope
##    (assumes that ZCGI has been installed)

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

my $query     = new CGI;
my $length    = $query->param("CONTENT_LENGTH");
my $len = $ENV{'CONTENT_LENGTH'};

my $form_info;

## read(STDIN, $form_info, $length); 
read(STDIN, $form_info, $len); 

print "Content-type: text/plain\n\n";

print "AAAAAAAAAA: $form_info, $length, $len";

