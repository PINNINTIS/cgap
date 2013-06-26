#!/usr/local/bin/perl

######################################################################
# GetCacheId.pl
#
######################################################################

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPConfig;
use DBI;
use Cache;
use Scan;

## print "Content-type: text/plain\n\n";

my ($chr, $setA, $setB) = @ARGV;

$setA =~ s/\[//g;
$setA =~ s/\]//g;
$setB =~ s/\[//g;
$setB =~ s/\]//g;

Scan($chr, $setA, $setB);

my $value = Check($chr, $setA, $setB);
if( $value =~ "Error" ) {
  print $value;
}
else {

  my $cache = new Cache(CACHE_ROOT, GXS_CACHE_PREFIX);

  my ($GXS_cache_id, $Filename) = $cache->MakeCacheFile();
  if ($GXS_cache_id != $CACHE_FAIL) {
    open(OUT, ">>$Filename") or die "Can not open file $Filename";
    close OUT;
    chmod 0666, $Filename;
    print $GXS_cache_id;
  }
  else{
    print "Error: Query Failed";
  }
}

####################################################
sub Check {
  my ($chr, $setA, $setB) = @_;

  $chr =~ s/\s+//g;
 
  if ( $chr eq "" ) {
    $chr = "All";
  }
   if( ( $chr > 22 or $chr < 1 ) and
      ( ($chr ne "X") and ($chr ne "Y") and ($chr ne "All") ) ) {    
     return "<br><br><center><b>Error: Not correct chromosome $chr</b></center>";
  }  

  my (%setAs, %setBs, %all_same_libs);
  for (split(", ", $setA)) {
    $setAs{$_} = 1 ;
  }
  for (split(", ", $setB)) {
    $setBs{$_} = 1 ;
  }
 
  for my $libA (keys %setAs) {
    if( defined $setBs{$libA} ) {      
      $all_same_libs{$libA} = 1;
    }  
  }
 
  for my $libB (keys %setBs) {
    if( defined $setAs{$libB} ) {
      $all_same_libs{$libB} = 1;
    }
  }
 
  my $common = scalar(keys %all_same_libs);
 
  if( $common > 0 ) {
    my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS, {AutoCommit=>0});
    if (not $db or $db->err()) {
      return "Error: There is an error, please contact help desk.";
    }
    my $names;
    my $lib_ids = join(",", keys %all_same_libs);    
 
    my $sql =
      "select name from $CGAP_SCHEMA.sagelibnames " .
      "where sage_library_id in( $lib_ids ) ";
    my $stm = $db->prepare($sql);
    if(not $stm) {
      $db->disconnect();
      return "Error: There is an error, please contact help desk.";
    }
    if(!$stm->execute()) {
      $db->disconnect();
      return "Error: There is an error, please contact help desk.";    }
 
    while( my ($name) = $stm->fetchrow_array()) {
      if( $names eq "" ) {
        $names = $name;
      }
      else {
        $names = $names . "</tr><tr>" . $name;
      }
    }
    my $output = "<table><tr>$names</tr></table>";
    $db->disconnect();    
    return "<br><br><center><b>Error: a library may not appear in both Pool A and Pool B. The following libraries appear in both pools:</b><br>$output<br></center>";
  }

}
