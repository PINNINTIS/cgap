#!/usr/local/bin/perl

#############################################################################
# test.pl
#

use strict;
use DBI;
use Bob;


BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
print "Content-type: text/plain\n\n";


my $file = "test.txt";
open(IN, $file) or die "Can not open";
while(<IN>) {
  chop;
  print "From text file: " . $_ . "<br><br>";
  ## return $_;
}
  my $$DB_INSTANCE = "cgdev";
  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    return "";
  }
  my $sql = "select * from $CGAP_SCHEMA.koder where KOD = '1710' ";
 
  my $stm = $db->prepare($sql);
 
  if (!$stm->execute()) {
     print STDERR "$sql\n";
     print STDERR "$DBI::errstr\n";
     print STDERR "execute call failed\n";
     return undef;
  }
 
  my ( $KOD, $KODTYP, $AKTIV, $INTERN, $BENAMNING, $KORTNAMN, $NOTERING );
  $stm->bind_columns(\$KOD, \$KODTYP, \$AKTIV, \$INTERN, \$BENAMNING, \$KORTNAMN, \$NOTERING);

  while ($stm->fetch) {
    print " From table koder: " . join("\t", $KOD, $KODTYP, $AKTIV, $INTERN, $BENAMNING, $KORTNAMN, 
$NOTERING ) . "<br><br>";
  }

  my $sql = "select * from $CGAP_SCHEMA.test";
 
  my $stm = $db->prepare($sql);
 
  if (!$stm->execute()) {
     print STDERR "execute call failed\n";
     return undef;
  }
 
  my ( $line);
  $stm->bind_columns(\$line);
  while ($stm->fetch) {    
    print "From table test " . $line . "<br>";

  }

