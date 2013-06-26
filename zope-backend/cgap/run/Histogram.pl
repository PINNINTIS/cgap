#!/usr/local/bin/perl

use strict;
use CGI;
use Scan;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

my $query       = new CGI;
my $prot_col    = $query->param("prot_col");
my $go_col      = $query->param("go_col");
my $filedata    = $query->param("filedata");

my (@row, $prot, $go, %hist);

print "Content-type: text/plain\n\n";

Scan($prot_col, $go_col, $filedata);

if (!$prot_col) {
  print "Must specify column containing protein accession\n";
  exit;
}
$prot_col =~ s/\s+//g;
if ($prot_col !~ /^\d+$/) {
  print "Must specify protein accession column as integer\n";
  exit;
}

if (!$go_col) {
  print "Must specify column containing GO id\n";
  exit;
}
$go_col =~ s/\s+//g;
if ($go_col !~ /^\d+$/) {
  print "Must specify GO column as integer\n";
  exit;
}
if (!$filedata) {
  print "Must specify file to be uploaded\n";
  exit;
}

if ($filedata) {
  while (<$filedata>) {
    s/\n//g;
    s/\r//g;
    s/^ +//;
    @row = split /\t/;
    $prot = $row[$prot_col-1];
    $go   = $row[$go_col-1];
    $prot =~ s/\s+$//;
    $go   =~ s/\s+$//;
    $hist{$go}{$prot} = 1;
  }
}

for my $x (keys %hist) {
  if ($x ne "") {
    print "$x\t" . scalar(keys %{ $hist{$x} }) . "\n";
  }
}
