#!/usr/local/bin/perl

#############################################################################
# BatchGeneFinder.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPGene;

my $query     = new CGI;

print "Content-type: text/plain\n\n";
print $query->start_multipart_form(-method=>'POST',-action=>'GetBatchGenes');
print $query->hidden(-name=>'PAGE',-value=>'1');
print $query->filefield(-name=>'FILENAME',-size=>30);
print "<BR>";
print $query->submit(-label=>'Create Gene List');
print $query->end_form;
