#!/usr/local/bin/perl

#############################################################################
#

use strict;
use Config; 
use CGI;
## use Thread;
use ithreads;
use DBI;
 
use constant$DB_USER         => "web";
use constant$DB_PASS         => "readonly";
use constant $DB_INSTANCE     => "cgprod";

my (%tmp_1, %tmp_2);
$tmp_1{0} = 8;
$tmp_1{1} = 88;
## for (my $i=0; $i<2000000; $i++) {
##   my $in = "AAAAAAAAAAAAAAAAA" . "$i";
##   $tmp_1{$in} = $i;
## }
for (my $i=0; $i<200; $i++) {
  my $in = "$i";
  $tmp_1{$in} = $i;
  my $ii = $i +10;
  $tmp_2{$in} = $ii;
}
## my $thr = new Thread \&sub1;
my $file = "/share/content/CGAP/run/TEST_1.txt";
my $thr = ithreads->new(\&sub1,$file,\%tmp_1,\%tmp_2, $db)->detach();
print "end\n"; 
## my @ReturnData = $thr->join;
## open(OUT, ">$file") or die "Can not open $file";
## print " $ReturnData[0] \n";

sub sub1 { 
  my ($file, $tmp_1_ref,$tmp_2_ref, $db1) =@_;
  my ($sql, $stm, $cid, $gene);
  open(OUT, ">$file") or die "Can not open $file";

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    return "";
  }
  sql($db);
  $sql = "select distinct cluster_number, GENE from " .
         "cgap2.hs_cluster " .
         "where cluster_number in(2, 4)";
 
  $stm = $db->prepare($sql);
  if (not $stm) {
    print STDERR "prepare call failed\n";
    return "";
  } else {
    if ($stm->execute()) {
      $stm->bind_columns(\$cid, \$gene);
      ## if ($stm->fetch) {
      while($stm->fetch) {
        print OUT "8888: $cid, $gene\n";
      }
    } else {
      print STDERR "execute failed\n";
      return "";
    }
  }
  $db->disconnect();

  for my $i (keys %{$tmp_1_ref}) {
    for my $j (keys %{$tmp_2_ref}) {
      my $sum = add($i, $j); 
      ## print OUT "$i, $j: $sum\n";
    }
  } 
  ## print OUT "In the thread\n"; 
  ## print OUT "$$tmp_1_ref{0}, $$tmp_1_ref{1}\n"; 
  ## print OUT "$$tmp_2_ref[0], $$tmp_2_ref[1]\n"; 
  ## print STDERR "In the thread\n"; 
  close OUT;
    for(my $i=0; $i<200000000; $i++){
    my $sum = add($i, 5);
  }

  return "In the thread\n"; 
}

sub add {
  my ($a, $b) =@_;
  my $sum = $a + $b;
  return $sum;
}
sub sql {
  my ($db) =@_;
  my ($sql, $stm, $cid, $gene);
  $sql = "select distinct cluster_number, GENE from " .
         "cgap2.hs_cluster " .
         "where cluster_number in(2, 4)";
 
  $stm = $db->prepare($sql);
  if (not $stm) {
    print STDERR "prepare call failed\n";
    return "";
  } else {
    if ($stm->execute()) {
      $stm->bind_columns(\$cid, \$gene);
      ## if ($stm->fetch) {
      while($stm->fetch) {
        print OUT "8888 9999: $cid, $gene\n";
      }
    } else {
      print STDERR "execute failed\n";
      return "";
    }
  }

}

