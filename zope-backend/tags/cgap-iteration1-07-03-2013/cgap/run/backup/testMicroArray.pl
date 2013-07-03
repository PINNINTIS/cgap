#!/usr/local/bin/perl

use MicroArray;
use strict;
use DBI;

use constant$DB_USER         => "web";
use constant$DB_PASS         => "readonly";
use constant $DB_INSTANCE     => "cgprod";

my @microarray_color_scale = (
  "0000FF",
  "3399FF",
  "66CCFF",
  "99CCFF",
  "CCCCFF",
  "FFCCFF",
  "FF99FF", 
  "FF66CC", 
  "FF6666",
  "FF0000"
);

my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
if (not $db or $db->err()) {
  print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
  print STDERR "$DBI::errstr\n";
  exit;
}

for my $e ("NCI60 STANFORD", "NCI60 NOVARTIS", "SAGE", "SAGE SUMMARY") {
  Do($e);
}

$db->disconnect;

######################################################################
sub Do {
  my ($e) = @_;

  print "########################################################\n";
  print "Doing $e ...\n";
  print "########################################################\n";
  print "\n";

  my $ma = new MicroArray($db, "cgap2", $e);
  if (! defined $ma) {
    die "bad return from new MicroArray";
  }
  
  my (%cid2probe, @simple_probe, @qualified_probe);
  $ma->LookupByCID([38481, 95577, 150423, 257266], \%cid2probe);
  for my $c (keys %cid2probe) {
    for my $p (@{ $cid2probe{$c} }) {
      print "cluster number = $c, probe = $p\n";
      push @qualified_probe, $p;
      $p =~ s/_\d+$//;
      push @simple_probe, $p;
    }    
  }
  print "\n";
  
  my (@ordering, @junk);
  $ma->OrderSet(\@simple_probe, \@ordering, \@junk);
  for (my $i = 0; $i < @ordering; $i++) {
    print "ordering: $i, $ordering[$i]\n";
  }
  print "\n";

  $ma->ReadView(\@qualified_probe);
  for my $p (@qualified_probe) {
    my @temp;
    $ma->ColorTheVector($p, \@microarray_color_scale, \@temp);
    print "$p: " . join(",", @temp) . "\n";
  }
  print "\n";

  my $col = 3;
  my $rval = 0.8;
  my $nvals = 10;
  my @vecs;
  my (@pos_cols, @pos_r, @pos_p, @neg_cols, @neg_r, @neg_p);

  ## with qualified probes
  print "qualified probes\n";
  $ma->Pivot(\@qualified_probe, $col, $rval, $nvals,
      \@pos_cols, \@pos_r, \@pos_p,
      \@neg_cols, \@neg_r, \@neg_p, \@vecs);
  for (my $i = 0; $i < @pos_cols; $i++) {
    print "positive[$i]: $pos_cols[$i], r = $pos_r[$i], p = $pos_p[$i]\n";
  }
  print "\n";
  for (my $i = 0; $i < @neg_cols; $i++) {
    print "negative[$i]: $neg_cols[$i], r = $neg_r[$i], p = $neg_p[$i]\n";
  }
  print "\n";

  undef @pos_cols;
  undef @pos_r;
  undef @pos_p;
  undef @neg_cols;
  undef @neg_r;
  undef @neg_p;
  undef @vecs;

  ## with unqualified probes
  print "unqualified probes\n";
  $ma->Pivot(\@simple_probe, $col, $rval, $nvals,
      \@pos_cols, \@pos_r, \@pos_p,
      \@neg_cols, \@neg_r, \@neg_p, \@vecs);
  for (my $i = 0; $i < @pos_cols; $i++) {
    print "positive[$i]: $pos_cols[$i], r = $pos_r[$i], p = $pos_p[$i]\n";
  }
  print "\n";
  for (my $i = 0; $i < @neg_cols; $i++) {
    print "negative[$i]: $neg_cols[$i], r = $neg_r[$i], p = $neg_p[$i]\n";
  }
  print "\n";

}
