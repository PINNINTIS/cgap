#!/usr/local/bin/perl

#############################################################################
# GetBatchGenomics.pl
#

use strict;
use CGI;
my %tag2allinfo;

  my $genomics_file = "/cgap/schaefec/current/SAGE/data/SAGEGENOMICSHS.dat";

  open (IN, $genomics_file) or die "Can not open $genomics_file\n";
  while (<IN>) {
    chop;
    my ($TAG, $CHROMOSOME, $START_POSITION) = split "\t", $_;
  }

