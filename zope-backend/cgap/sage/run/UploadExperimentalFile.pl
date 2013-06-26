#!/usr/local/bin/perl

#############################################################################
# UploadExperimentalFile.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use DKView;
use Scan;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $org       = $query->param("ORG");
my $filename  = $query->param("FILENAME");
my $filedata  = $query->param("filenameFILE");

print "Content-type: text/plain\n\n";

Scan($base, $org, $filename, $filedata);
print UploadExperimentalFile_1($base, $org, $filename, $filedata);
