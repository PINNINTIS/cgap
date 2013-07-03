#!/usr/local/bin/perl

######################################################################
#  Processing_Existing_Lib_data.pl
######################################################################
use strict;
use DBI;
use CGAPConfig;
use Cache;
my $CACHE_FAIL = 0;

my $DB_USER         = "cgap2";
my $DB_PASS         = "pagc";
my $$DB_INSTANCE     = "cgprod";

my @chr_order = ("1", "2", "3", "4", "5", "6", "7", "8", "9",
     "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
     "20", "21", "22", "X", "Y");

my $dk_exist_cache = new Cache(CACHE_DK_EXIST_ROOT, DK_CACHE_PREFIX);

my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE, $DB_USER, $DB_PASS);
if (not $db or $db->err()) {
  print STDERR "Cannot connect to " . $DB_USER . "@" . $$DB_INSTANCE . "\n";
  exit();
}
 
my $dkmap_file = "/share/content/CGAP/SAGE/data/dkmap.dat";

Processing_Existing_Lib_data($db, $dkmap_file);

$db->disconnect();

######################################################################
sub Processing_Existing_Lib_data {
  my ($db, $dkmap_file) = @_;
 
  my ($sql, $stm);
  my @all_file_names;

  my $sql = "select FILE_NAME from $CGAP_SCHEMA.dksagelibinfo ";
 
  my $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
  }
  if(!$stm->execute()) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
  }
 
  while( my ($file_name) = $stm->fetchrow_array()) {
    Map_update_dkmap($db, $file_name, $dkmap_file);
  }
}
######################################################################
sub Map_update_dkmap {
  my ($db, $file_name, $dkmap_file) = @_;
 
  my (%tag2allinfo, %chr_position2allinfo);
  my (@all_lines, @good_lines, @dup_lines, @no_result_lines);
 
  my ($list);
  my ($sql, $stm);
  my %goodInput;
  my %tags;
  my $lines;
  my $count = 0;
  my (%dup_tags);
  my %exp;
  my (%freq, %chr_2_mapped_id, %chr_2_smoothed_id);
  my %mapped_tags;
  my %not_mapped_tags;
  my @mapped_lines;
  my @input_tags;
  my %unique_input_tags;
  my $total_input_tags;
  my $total_input_unique_tags;
  my $total_mapped_tags;
  my $total_mapped_unique_tags;
  my $N_VIRTUAL_TAGS;
  
  $N_VIRTUAL_TAGS = Get_total_of_dkmap($db);
 
  my $full_name = CACHE_DK_EXIST_ROOT . "/" . $file_name;
 
  open( IN, $full_name ) or die "Can't open $full_name \n"; 
 
  while (<IN>) {
    chop;
    $_ =~  s/^\s+//;
    $_ =~  s/\s+$//;
    if ($_ eq "") {
      next;
    }
    else {
      my ($tag, $freq) = split /\t/, $_;
      $exp{$tag} += $freq;
      $total_input_tags = $total_input_tags + $freq;
      $unique_input_tags{$tag} = 1;
    }
  }
 
  $total_input_unique_tags = scalar(keys %unique_input_tags);
  my $mapped;
  my $not_mapped;
 
  open (IN, $dkmap_file) or die "Can't open $dkmap_file \n";
  while(<IN>) {
    chop;
    my ($tag, $chr, $pos, $strand, $tag_num) = split "\t", $_;
    my $freq;
    if (defined $exp{$tag}) {
      $freq = $exp{$tag};
      $total_mapped_tags = $total_mapped_tags + $freq;
      $total_mapped_unique_tags++;
    } else {
      $freq = 0;
    }
    push @{ $freq{$chr} }, $freq;
  }
  close (IN);
 
  my $overall_avg = $total_mapped_tags/$N_VIRTUAL_TAGS;
 
  for my $chr (@chr_order) {
    for my $f (@{ $freq{$chr} }) {
      $f = sprintf("$f\t%.2f\n", $f / $overall_avg)
    }
  }
 
  my $total_not_mapped_tags = $total_input_tags - $total_mapped_tags;
  my $total_not_mapped_unique_tags =
          $total_input_unique_tags - $total_mapped_unique_tags;
 
  my ($mapped_cache_id, $cache_filename) = $dk_exist_cache->MakeCacheFile();
  if ($mapped_cache_id == $CACHE_FAIL) {
    print "Failed to make DKCache File. <br>";
  }
 
  for my $chr (@chr_order) {
    my $file = $cache_filename . "." . $chr;
    open ("OUT", ">$file") or die "Can not open $file \n";
    my $data = join "", @{ $freq{$chr} };
    print OUT $data;
    close (OUT);
    chmod 0666, $file;
    undef $data;
  }
 
  Update_dksagelibinfo($db, $file_name, $mapped_cache_id, 
                       $total_mapped_tags, 
                       $total_mapped_unique_tags, 
                       $total_input_tags, 
                       $total_input_unique_tags); 
}

######################################################################
sub Get_total_of_dkmap {
  my ($db) = @_;
  my ($sql, $stm);

  $sql = "select count(tag) from $CGAP_SCHEMA.dkmap ";
 
  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
  }
  if(!$stm->execute()) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
  }
 
  while( my ($total) = $stm->fetchrow_array()) {
    if( $total == 0 ) {
      print "The table DKMAP is empty.\n";
      return "";
    }
    else {
      return $total;
    }
  }
}

######################################################################
sub Update_dksagelibinfo {
  my ($db, $file_name, $mapped_cache_id,
      $total_mapped_tags,
      $total_mapped_unique_tags,
      $total_input_tags,
      $total_input_unique_tags) = @_;

  my ($update_sql, $update_stm);
  my $update_sql = " update $CGAP_SCHEMA.dksagelibinfo " .
         " set TAGS_PLUS = $total_input_tags, " .
         "     UTAGS = $total_input_unique_tags, " .
         "     MAPPED_TAGS_PLUS = $total_mapped_tags, " .
         "     MAPPED_UTAGS = $total_mapped_unique_tags, " .
         "     MAPPED_CACHE_ID = $mapped_cache_id " .
         " where FILE_NAME = '$file_name' ";
  my $update_stm = $db->prepare($update_sql);
  if(not $update_stm) {
    print STDERR "$update_sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    exit;
  }
  if(!$update_stm->execute()) {
    print STDERR "$update_sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    exit;
  }
}
######################################################################
