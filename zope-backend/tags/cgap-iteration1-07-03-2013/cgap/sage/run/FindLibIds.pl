#!/usr/local/bin/perl

my (%libids );
my ($id, $lib, $name);

sub GetLibIds {

  open(SAGE, "<SageNames.txt");

  while (<SAGE>) {
    chop;
    if (/(\d+)\t(.*)$/) {
      $id = $1;
      $lib = $2;
      $libids{$lib} = $id;
    }
  }

  close(SAGE);
}

sub PutLibIds {

  open(EXPV, "<experimental_viewer.txt");
  open(IDS,   ">SageLibIds.txt");

  while (<EXPV>) {
    chop;
    if ($_ =~ /^([\w\d\s\-]+)\t+(.*)$/) {
      $name = $1;
      $lib = $2;
      if (defined $libids{$lib}) {
        print IDS "$name\t$lib\t$libids{$lib}\n";
      } else {
        print "NOT FOUND $name $lib\n";
      }
    } elsif ($_ =~ /^\t+(.*)$/) {
      $lib = $1;
      if (defined $libids{$lib}) {
        print IDS "$name\t$lib\t$libids{$lib}\n";
      } else {
        print "NOT FOUND $name $lib\n";
      }
    } else {
      print "SKIPPING $_\n";
      $name = '';
    }
  }

  close IDS;
  close EXPV;
}

###################################################################

GetLibIds();
PutLibIds();

exit;
