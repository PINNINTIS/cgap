#!/usr/local/bin/perl

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SPQuery;

my $query       = new CGI;
my $cmd         = $query->param("cmd");
my $filedata    = $query->param("filedata");
my $acc         = $query->param("acc");
my $gofile      = $query->param("gofile");

print "Content-type: text/plain\n\n";

if (!$cmd) {
  print "No command option specified\n";
  exit;
}
if (!$filedata && !$acc) {
  print "Must provide accession or name of file contain accessions\n";
  exit;
}

my ($x, @x);
if ($filedata) {
  while (<$filedata>) {
    s/\n//g;
    s/\r//g;
    s/^ +//;
    ($x) = split /\t/;
    $x =~ s/\s+$//;
    if ($cmd =~ "ll2") {
      if ($x =~ /^\d+$/) {
        push @x, $x;
      }
    } elsif ($x) {
      push @x, uc($x);
    }
  }
} elsif ($acc) {
  for $x (split(",", $acc)) {
    $x =~ s/\s+$//;
    if ($cmd =~ "ll2") {
      if ($x =~ /^\d+$/) {
        push @x, $x;
      }
    } elsif ($x) {
      push @x, uc($x);
    }
  }
}
if (@x == 0) {
  print "Empty file\n";
  exit;
}
my ($g, %g);
if ($gofile) {
  while (<$gofile>) {
    s/\n//g;
    s/\r//g;
    s/^ +//;
    s/^GO://i;
    s/^ +//;
    ($g) = split /\t/;
    $g =~ s/\s+$//;
    if ($g) {
      $g{uc($g)} = 1;
    }
  }
}

if ($cmd eq "spinfo") {
  print join("\n", @{ SPInfo(\@x) })    . "\n";
} elsif ($cmd eq "sp2other") {
  print join("\n", @{ SP2Xrefs(\@x) })  . "\n";
} elsif ($cmd eq "sp2go") {
  print join("\n", @{ SP2GO(\@x, \%g) })     . "\n";
} elsif ($cmd eq "sp2ll") {
  print join("\n", @{ SP2LL(\@x) })     . "\n";
} elsif ($cmd eq "ll2sp") {
  print join("\n", @{ LL2SP(\@x) })     . "\n";
} elsif ($cmd eq "ll2acc") {
  print join("\n", @{ LL2Acc(\@x) })    . "\n";
} elsif ($cmd eq "ll2go") {
  print join("\n", @{ LL2GO(\@x, \%g) })    . "\n";
} elsif ($cmd eq "other2sp") {
  print join("\n", @{ Xrefs2SP(\@x) })    . "\n";
} else {
  print "unrecognized command $cmd\n";
}

