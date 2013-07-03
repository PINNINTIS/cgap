######################################################################
# DKView.pm
######################################################################

use strict;
use DBI;
use CGAPConfig;
use Cache;
use Paging;
use CGI;

use constant ORACLE_LIST_LIMIT => 500;

use constant BIN_SIZE => 100;
my (%window_value, %high_window_value, %low_window_value);
my (@start, @end, @window_val, @tag_num);
my (@high_start, @high_end, @high_window_val);
my (@low_start, @low_end, @low_window_val);
my (%binned_data);
my (%binned_data_detail);
my (%binned_data_high_detail);
my (%binned_data_low_detail);
my (%data, %del_detect, %amp_detect);
my (%ord2bp, %ord2tag, %ord2num);
my (%amp, %del, %dkmap);
my $WIDTH = 400;
my $DETAIL_WIDTH = 100;
my $WIDTH_HIT = ($WIDTH/BIN_SIZE)/2;
my $HALF_WIDTH = $WIDTH/2 + 1;
my $HIT_POSITION = $WIDTH/2 + 26;
my $SCALE = 20;
my $DETAIL_SCALE = 100;
my $UCSC_DB = "hg17";
my $DETAIL_SCALAR = 2;
my $DETAIL_MAX = 350;
my $DETAIL_WARNING = 0;
my %ORGANISM_NAME  = (
  "Hs"                 => "Human",
  "Mm"                 => "Mouse"
);

my $BASE;

my $dk_cache = new Cache(CACHE_ROOT, DK_CACHE_PREFIX);
my $dk_exist_cache = new Cache(CACHE_DK_EXIST_ROOT, DK_CACHE_PREFIX);
my $CACHE_FAIL = 0;
my $map_f = "/share/content/CGAP/SAGE/data/dkmap.dat";
my $map_without_tagnum_f = "/share/content/CGAP/SAGE/data/dkmap_without_tagnum.dat";
my (%result, %DEL_RATIO, %AMP_RATIO);
my $DK_EXISTING_LOW_LIMIT = 100000;

my @chr_order = ("1", "2", "3", "4", "5", "6", "7", "8", "9",
     "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
     "20", "21", "22", "X", "Y");

######################################################################
sub GetDKLibrary_1 {
  my ($base) = @_;

  my ($db, $sql, $stm);
  $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    exit();
  }
 
  my $output =
    "<table border=\"1\" width=92% cellpadding=2>" .
    "<tr bgcolor=\"#666699\">" .
    "<td width=35%><font color=\"white\"><b>Library Name</b></font></td>" .
    "<td width=14%><font color=\"white\"><b>Tissue</b></font></td>" .
    "<td width=14%><font color=\"white\"><b>Histology</b></font></td>" .
    "<td width=14%><font color=\"white\"><b>Total Tags</b></font></td>" .
    "<td width=14%><font color=\"white\"><b>Mapped Tags</b></font></td>" .
    "<td width=9%><font color=\"white\"><b>DKView</b></font></td>" .
    "</tr>";
 
  $sql = "select NAME, TAGS_PLUS, MAPPED_TAGS_PLUS, THE_TISS, " .
         "THE_HIST, FILE_NAME, MAPPED_CACHE_ID " .
         "from $CGAP_SCHEMA.DKSAGELIBINFO order by NAME"; 
 
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
  while(my ($NAME, $TAGS_PLUS, $MAPPED_TAGS_PLUS, $THE_TISS, $THE_HIST, 
            $FILE_NAME, $MAPPED_CACHE_ID ) = $stm->fetchrow_array()) {
    $output = $output . 
       "<tr>" .
       "<td width=35% NOWRAP>" .
       "<a href=javascript:spawn(\"/SAGE/SAGEDKLibInfo?LIBNAME=$NAME&ORG=Hs\")>$NAME</a></td>" .
       "<td width=14% NOWRAP>$THE_TISS</td>" .
       "<td width=14% NOWRAP>$THE_HIST</td>" .
       "<td width=14% NOWRAP>" .
       "<a href=javascript:spawn(\"/SAGE/DKRawDataDownload?ORG=Hs&FILENAME=$FILE_NAME\")>$TAGS_PLUS</a>" .
       "</td>" .
       "<td width=14% NOWRAP>" .
       "<a href=javascript:spawn(\"/SAGE/DKDownload?ORG=Hs&CACHE_ID=$MAPPED_CACHE_ID&FILENAME=$FILE_NAME\")>$MAPPED_TAGS_PLUS</a>" .
       "</td>" .
       "<td width=9% NOWRAP>" .
       "<a href=javascript:spawn(\"/SAGE/DK_Query?ORG=Hs&LIBNAME=$NAME&FILENAME=$FILE_NAME\")>DkView</a>" .
       "</td>" .
       "</tr>";
  }
 
  $db->disconnect();
  $output = $output . "</table>";
  return $output;

}

######################################################################
sub DK_Query_1 {
  my ($base, $org, $libname) = @_;

  ##push @lines, "<br><center>Filename: $filename; Window size: $window_size </center><br><br>";
  my (@lines, @image_map);

  my ($name, $mapped_cache_id, $filename, $total_mapped_tags,
      $total_not_mapped_tags, $total_input_tags, $total_mapped_unique_tags,
      $total_not_mapped_unique_tags,
      $total_input_unique_tags);

  my ($db, $sql, $stm);
  $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    exit();
  }
 
  $sql = "select NAME, FILE_NAME, MAPPED_CACHE_ID, TAGS_PLUS, UTAGS, " .
         "MAPPED_TAGS_PLUS, MAPPED_UTAGS " .
         "from $CGAP_SCHEMA.DKSAGELIBINFO where NAME = '$libname' ";
 
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

  $stm->bind_columns(\$name, \$filename, \$mapped_cache_id, 
                     \$total_input_tags, \$total_input_unique_tags, 
                     \$total_mapped_tags, \$total_mapped_unique_tags);
  while ($stm->fetch) {
    $total_not_mapped_tags = $total_input_tags - $total_mapped_tags;
    $total_not_mapped_unique_tags = $total_input_unique_tags -
                                    $total_mapped_unique_tags;
  }
 
  $db->disconnect();

  return Make_upload_html ($org, $mapped_cache_id, $filename, 
                           $total_mapped_tags, $total_not_mapped_tags, 
                           $total_input_tags, $total_mapped_unique_tags, 
                           $total_not_mapped_unique_tags,
                           $total_input_unique_tags);
}

######################################################################
sub SAGEDKLibPage_1 {
  my ($base, $libname, $org) = @_;

  my $BASE = $base;

  my ($DUKE_name, $NCBI_name, $keywords);
  my $organism = ($org eq 'Hs') ? "Homo sapiens" : "Mus musculus";
  my ($tags_plus, $tags, $utags);
  my ($tissue, $histology, $preparation, $mutations,
      $patient_age, $patient_sex, $other_info);
  my ($tag_enzyme, $anchor_enzyme, $supplier, $producer,
      $laboratory, $references);

  my ($db, $sql, $stm);
  my ($name, $nametype);
  my ($reference, $pubmed_id);
  my (@ref_array);

  my %nice_enzyme_html = (
    "BsmF I"  => "<i>Bsm</i><font face=\"Times New Roman\">FI</font>",
    "Nla III" => "<i>Nla</i><font face=\"Times New Roman\">III</font>",
    "Mme I"   => "<i>Mme</i><font face=\"Times New Roman\">I</font>"
  );

  my (@rows);

  $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    exit();
  }

  $sql = "select " .
      "name, keywords, " .
      "tags_plus, utags, mapped_tags_plus, mapped_utags, " .
      "the_tiss, the_hist, ORGANISM, METHOD, preparation, mutations, " .
      "patient_age, patient_sex, other_info, " .
      "tag_enzyme, anchor_enzyme, supplier, producer, " .
      "laboratory, reference " .
      "from $CGAP_SCHEMA.dksagelibinfo " .
      "where name = '$libname'";

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

  my ($name, $keywords,
      $tags_plus, $utags, $mapped_tags_plus, $mapped_utags,
      $tissue, $histology, $org, $method, $preparation, $mutations,
      $patient_age, $patient_sex, $other_info,
      $tag_enzyme, $anchor_enzyme, $supplier, $producer,
      $laboratory, $reference)
       = $stm->fetchrow_array();
  $stm->finish();

  $tags_plus = Thousands($tags_plus);
  $mapped_tags_plus = Thousands($mapped_tags_plus);
  $utags     = Thousands($utags);
  $mapped_utags     = Thousands($mapped_utags);
  if (defined $nice_enzyme_html{$tag_enzyme}) {
    $tag_enzyme    = $nice_enzyme_html{$tag_enzyme};
  }
  if (defined $nice_enzyme_html{$anchor_enzyme}) {
    $anchor_enzyme = $nice_enzyme_html{$anchor_enzyme};
  }
  if ($tissue eq "mammary gland" && $org eq "Hs") {
    $tissue = "breast";
  }

  $references = $reference;

  $db->disconnect();

  return Make_lib_page_html ($name, $organism, $keywords, $tags_plus, 
      $mapped_tags_plus, $utags, $mapped_utags, $tissue, $histology, 
      $preparation, $mutations, $patient_age, $patient_sex, $other_info, 
      $tag_enzyme, $anchor_enzyme, $supplier, $producer, $laboratory, 
      $references);
}

######################################################################
sub UploadExperimentalFile_1 {
  my ($base, $org, $filename, $filedata) = @_;
 
  $BASE = $base;
 
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
 
  if( $filename eq "" ) {
    return "Please enter the file name.";
  }

  $N_VIRTUAL_TAGS = Get_total_of_dkmap(); 
 
  my @tempArray;
  if( $filedata =~ /\r/ ) {
    @tempArray = split "\r", $filedata;
  }
  else {
    @tempArray = split "\n", $filedata;
  }
 
  for (my $t = 0; $t < @tempArray; $t++ ) {
    $tempArray[$t] =~  s/^\s+//;
    $tempArray[$t] =~  s/\s+$//;
    if ($tempArray[$t] eq "") {
      next;
    }
    else {
      my ($tag, $freq) = split /\t/, $tempArray[$t];
      $exp{$tag} += $freq;
      $total_input_tags = $total_input_tags + $freq;
      $unique_input_tags{$tag} = 1;
    }
  }

  $total_input_unique_tags = scalar(keys %unique_input_tags);
  my $mapped;
  my $not_mapped;

  open (IN, $map_f) or die "Can't open $map_f";
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

  my ($mapped_cache_id, $cache_filename) = $dk_cache->MakeCacheFile();
  if ($mapped_cache_id == $CACHE_FAIL) {
    print "Failed to make DKCache File. <br>";
  }

  for my $chr (@chr_order) {
    my $file = $cache_filename . "." . $chr;
    open ("OUT", ">$file") or die "Can not open $file \n";
    my $data = join "", @{ $freq{$chr} };
    print OUT $data;
    close (OUT);
    undef $data;
  }

  return Make_upload_html ($org, $mapped_cache_id, $filename, 
                           $total_mapped_tags, $total_not_mapped_tags, 
                           $total_input_tags, $total_mapped_unique_tags, 
                           $total_not_mapped_unique_tags,
                           $total_input_unique_tags);

}

######################################################################
sub Get_total_of_dkmap {

  my ($db, $sql, $stm);
  $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    exit();
  }
 
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

  $db->disconnect();
}
 
######################################################################
sub DKDownload_1 {
  my ($base, $mapped_cache_id) = @_;
  
  my (%freq, %chr_2_id);

  get_data_from_dkmap_file();
 
  my @output;
  push @output, "Tag\tChr\tPosition\tStrand\tFreq\n";

  for my $chr (@chr_order) {
    my $file;
    if( $mapped_cache_id >= 100000 ) {
      $file = CACHE_DK_EXIST_ROOT . "DK.$mapped_cache_id.$chr";
    }
    else {
      $file = CACHE_ROOT . "DK.$mapped_cache_id.$chr";
    }
    open(IN, "$file") or die "Can't open $file, the cache file $file expired.";
    my $count = 0;
    while (<IN>) {
      chop;
      my ($raw_freq, $normalized_freq) = split /\t/, $_;
      if( $raw_freq != 0 ) {
        push @output, @{ $dkmap{$chr} }[$count] . "\t" . $raw_freq . "\n";
      }
      $count++;
    }
    close (IN);
  }

  return "", @output;
}

######################################################################
sub DKRegionDownload_1 {

  my ($base, $org, $chr, $mapped_cache_id, 
                            $start_pos, $end_pos, $filename) = @_;

  my (%freq, %chr_2_id);

  my ($start, $end); ## need to use mapped file, so get all for the chr
  my $need_tag_num = 0;
  get_data_from_dkmap( $chr, $start, $end, $need_tag_num);
 
  my @output;
  push @output, "Tag\tChr\tPosition\tStrand\tFreq\n";

  my $file; 
  if( $mapped_cache_id >= 100000 ) {
    $file = CACHE_DK_EXIST_ROOT . "DK.$mapped_cache_id.$chr"; 
  }
  else {
    $file = CACHE_ROOT . "DK.$mapped_cache_id.$chr";
  }
  open(IN, "$file") or die "Can't open $file, the cache file $file expired";
  my $count = 0;
  while (<IN>) {
    chop;
    my ($raw_freq, $normalized_freq) = split /\t/, $_;
    my ($tag, $chr, $pos, $strand) = split "\t", @{ $dkmap{$chr} }[$count];
    if( $pos >= $start_pos and $pos <= $end_pos ) {
      if( $raw_freq != 0 ) {
        push @output, @{ $dkmap{$chr} }[$count] . "\t" . $raw_freq . "\n";
      }
    }
    $count++;
  }
  close (IN);

  return "", @output;
}

######################################################################
sub DKRawDataDownload_1 {
  my ($base, $filename) = @_;

  my $raw_file = CACHE_DK_EXIST_ROOT . $filename;
  open(IN, "$raw_file") or die "Can't open $raw_file.";
 
  my @output;
  while (<IN>) {
    push @output, $_;
  }
  close (IN);

  return "", @output;
}

######################################################################
sub DKView_1 {
  my ($base, $org, $mapped_cache_id, $window_size, $filename,
      $DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD) = @_;
 
  my %freq;
  my @mapped_lines;
  my $bin_size = BIN_SIZE;
  my ($tag, $chr, $pos, $strand, $tag_num, $freq);
  my (%mapped_data, $n_virtual_tags, $sum_freq);
  my (%freq);
  my (@window_info);
  my $data;
  my (%chr_2_id);

  if ($window_size % 2 != 0) {
    $window_size++;
  }
  my $half_window = $window_size / 2;
   
  for my $chr (@chr_order) {
    my $file; 
    if( $mapped_cache_id >= 100000 ) {
      $file = CACHE_DK_EXIST_ROOT . "DK.$mapped_cache_id.$chr"; 
    }
    else {
      $file = CACHE_ROOT . "DK.$mapped_cache_id.$chr";
    }
    open(IN, "$file") or die "Can't open $file, the cache file $file expired";
    my $count = 0;
    while (<IN>) {
      chop;
      my ($raw_freq, $normalized_freq) = split /\t/, $_;
      push @{ $freq{$chr} }, $normalized_freq;
    }
    close (IN);
  }

  my %n_virtual_tags_per_chr;
  for my $chr (@chr_order) {
    $n_virtual_tags_per_chr{$chr} = @{ $freq{$chr} };
  }

  for $chr (@chr_order) {
    for (my $tag_num = 0; $tag_num < @{ $freq{$chr} }; $tag_num++) {
      $window_value{$chr}[$tag_num] = sprintf("%.2f",
        ComputeWindow($chr, $tag_num, 
        $half_window, \%n_virtual_tags_per_chr, $window_size, \%freq));
    }
  }

  my ($smoothed_cache_id, $filename) = $dk_cache->MakeCacheFile();
  if ($smoothed_cache_id == $CACHE_FAIL) {
    print "Failed to make DKCache File. <br>";
  }

  for my $chr (@chr_order) {
    my $file = $filename . "." . $chr;
    open ("OUT", ">$file") or die "Can not open $file \n";
    my $data = (join "\n", @{ $window_value{$chr} }) . "\n";
    print OUT $data;
    close (OUT);
    undef $data;
  }
 
  ReadData();

  Hunt_anomalies ($DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD);

  return Make_Display_amp_del_page( 
               $org, $smoothed_cache_id, $bin_size, $window_size,
               $mapped_cache_id, $DEL_WIDTH, $DEL_THRESHHOLD, 
               $AMP_WIDTH, $AMP_THRESHHOLD, $filename); 

}

######################################################################
sub ComputeWindow {
  my ($chr, $tag_num, $half_window, $n_virtual_tags_per_chr_ref,
      $window_size, $freq_ref) = @_;
 
  ## actually, the window is half_window tags on either side
  ## of the focal tag
 
  my $j;
  my %freq = %{$freq_ref};
  my $n_tags_in_chr = $$n_virtual_tags_per_chr_ref{$chr};
  if ($tag_num - $half_window < 0) {
    $j = $tag_num;
  } elsif ($tag_num + $half_window > $n_tags_in_chr) {
    $j = $tag_num - $n_tags_in_chr;
  } else {
    $j = $half_window;
    if ($tag_num > $j && $tag_num < $n_tags_in_chr - $half_window - 1) {
      my $val = 
           ( $window_value{$chr}[$tag_num - 1] * ($window_size + 1) -
             $freq{$chr}[$tag_num - $half_window - 1] +
             $freq{$chr}[$tag_num + $half_window]
           ) / ($window_size + 1);
      if( $val < 0 ) {
        return 0; 
      }
      else {
        return $val;
      }
    }
  }
 
  ## it's one end or the other
 
  my $sum;
  for (my $i = $tag_num - $j; $i <= $tag_num + $j; $i++) {
    $sum += $freq{$chr}[$i];
  }
  return $sum / (($j * 2) + 1);
}

######################################################################
sub DKView_All_1 {
  my ($base, $org, $mapped_cache_id, $smoothed_cache_id,
      $window_size, $filename,
      $DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD) = @_;

  my $n;
  my ($tag, $chr, $pos, $strand, $tag_num, $freq, $normal_freq, $window_val);
  my ($last_chr);
  my (@lines, %chr_2_image_id, %chr_2_mapped_id, %chr_2_smoothing_id);
  my (@image_map);
  my (%chr_2_id, %window_vals);
  my $bin_size = BIN_SIZE;
  my (%max);

  for my $chr (@chr_order) {
    $max{"$chr"} = 0;
  }

  for my $chr (@chr_order) {
    my $file = CACHE_ROOT . "DK.$smoothed_cache_id.$chr";
    open(IN, "$file") or die "Can't open $file, the cache file $file expired";
    my $count = 0;
    while (<IN>) {
      chop;
      push @{ $window_vals{$chr} }, $_;
    }
    close (IN);
  }

  open (IN, $map_f) or die "Can't open $map_f";
  while(<IN>) {
    chop;
    my ($tag, $chr, $pos, $strand, $tag_num) = split "\t", $_;

    if ($last_chr && $last_chr ne $chr) {
      DoBin($last_chr, $n, $bin_size, \%max);
      $n = 0;
    }
    $last_chr = $chr;
    push @window_val, $window_vals{$chr}[$n];
    push @start, $pos;
    $n++;
    if ($n % $bin_size == 0) {
      DoBin($chr, $n, $bin_size, \%max);
    }
  }
  close (IN);
 
  if ($n % $bin_size > 0) {
    DoBin($chr, $n, $bin_size, \%max);
  }
 
  for my $chr (@chr_order) {
    my $chrmapname = "chrmap" . $chr;
    push @image_map, "<map name=\"$chrmapname\">";
    $chr_2_image_id{$chr} =  
      Graph($org, $chr, \@image_map, $window_size, 
            $filename, $max{$chr}, $mapped_cache_id,
            $DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD);
    push @image_map, "</map>";
  }
 
  for my $chr (@chr_order) {
    my $id = $chr_2_image_id{$chr};
    my $chrmapname = "chrmap" . $chr;
    push @lines, "<img src=\"DKImage?CACHE=$id&CHR=$chr\" border=0 usemap=\"#$chrmapname\"><br>";
  }

  push @lines, @image_map;

  return (join "", @lines);
}
 
######################################################################
sub DoBin {
  my ($chr, $n, $bin_size, $max_ref) = @_;
 
  my $bn = int($n / $bin_size);
  if ($n % $bin_size > 0) {
    $bn++;
  }
  my $s_pos = $start[0];
  my $e_pos = $start[$#start];
  my $mid = int(@window_val / 2);
  my $avg = $window_val[$mid];
  push @{ $binned_data{$chr} }, join("\t",
      $bn,
      $chr,
      $s_pos,
      $e_pos,
      $n - scalar(@window_val) + 1,
      $n,
      $avg
    );

  if( ($n - scalar(@window_val) + 1) > 1 ) {
    if( $avg > $$max_ref{$chr} ) {
      $$max_ref{$chr} = $avg;
    }
  }

  undef @start;
  undef @end;
  undef @window_val;
}
 
######################################################################
sub Graph {
  my($org, $chr, $image_map_ref, $window_size, 
     $filename, $max, $mapped_cache_id,
     $DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD) = @_;
 
use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  my $GRAPH_HEIGHT        = 200;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * @{ $binned_data{$chr} };
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 30;
  my $IMAGE_WIDTH         = $GRAPH_WIDTH  + 200;
  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);
 
  # allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
 
  my %COLORS;
  $COLORS{white}       = $im->colorAllocate(255,255,255);
  $COLORS{black}       = $im->colorAllocate(0,0,0);
  $COLORS{lightgray}   = $im->colorAllocate(240,240,240);
  $COLORS{red}         = $im->colorAllocate(255,0,0);
  $COLORS{blue}        = $im->colorAllocate(0,0,255);
  $COLORS{lightblue}   = $im->colorAllocate(0,255,255);
  $COLORS{green}       = $im->colorAllocate(0,255,0);

  my $color;

  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );
 
  if( $max >=0.5 and $max <= 4 ) {
    for (my $y0 = $GRAPH_HEIGHT; $y0 >= 0; $y0 = $y0 - 50) {
      my $x0 = 0;
      $im->string(gdSmallFont, $x0, $y0, int(($GRAPH_HEIGHT - $y0)/50), $COLORS{black});
    }
  }
  elsif ($max > 4) {
    my $x0 = 0;
    my $y0 = $GRAPH_HEIGHT;
    $im->string(gdSmallFont, $x0, $y0, 0, $COLORS{red});
    $y0 = $GRAPH_HEIGHT - int(50 * ($max/($max + 1)) * 4);
    $im->string(gdSmallFont, $x0, $y0, $max, $COLORS{red});
  }
  else {
    my $x0 = 0;
    my $y0 = $GRAPH_HEIGHT;
    $im->string(gdSmallFont, $x0, $y0, 0, $COLORS{red});
    $y0 = $GRAPH_HEIGHT - int(50 * ($max/($max + 0.1)) * 4);
    $im->string(gdSmallFont, $x0, $y0, $max, $COLORS{red});
  }

  my $last_val;

  ## start from 0 or 1?
  ## for (my $i = 1; $i < @{ $binned_data{$chr} } - 1; $i++ ) {
  for (my $i = 0; $i < @{ $binned_data{$chr} } - 1; $i++ ) {

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
                                         = split("\t", $binned_data{$chr}[$i]);

    my $x0 = $PIX_PER_INTERVAL * ($i - 1);
    my $x1 = $PIX_PER_INTERVAL * $i;
    my $y0;
    if( $max >= 0.5 and $max <= 4 ) {
      $y0 = $GRAPH_HEIGHT - int(50 * $last_val);
    }
    elsif( $max > 4 ) {
      $y0 = $GRAPH_HEIGHT - int(50 * ($last_val/($max + 1)) * 4);
    }
    else {
      $y0 = $GRAPH_HEIGHT - int(50 * ($last_val/($max + 0.1)) * 4);
    }
    my $y1;
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }

    $color = $COLORS{red};

    if ($x0 == $x1) {
      $im->line (
          $x0+30,
          $y0,
          $x1+30,
          $y1,
          $color
      );
    } else {
      $im->filledRectangle (
          $x0+30,
          $y0,
          $x1+30,
          $y1,
          $color
      );
    }
    ## if( $chr == 1 and $i < 200 ) {
    ##   print "8888: $x0+30, $y0, $x1+30, $y1 <br>"; 
    ## }
    $last_val = $value;
    my $x0_pos = $x0+30;
    my $x1_pos = $x1+30;
    push @{ $image_map_ref },
      "<area shape=rect coords=\"$x0_pos,$y0,$x1_pos,$y1\" " .
      "href=javascript:spawn(\"DKViewDetail?ORG=$org&CHR=$chr&POS=$start_tag&START_POS=&END_POS=&WINDOWSIZE=$window_size&FILENAME=$filename&MAPPED_DATA_CACHE_ID=$mapped_cache_id&DELWIDTH=$DEL_WIDTH&DELTHRESHHOLD=$DEL_THRESHHOLD&AMPWIDTH=$AMP_WIDTH&AMPTHRESHHOLD=$AMP_THRESHHOLD\")>";
  }
  
  if( $max >= 0.5 and $max <= 4 ) {
    my $x0 = 0 + 30;
    my $x1 = $GRAPH_WIDTH + 30;
    my $y0 = $GRAPH_HEIGHT - int(50 * 1);
    my $y1 = $y0;
    $im->line($x0, $y0, $x1, $y1, $COLORS{white});
  }

  $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+10, "Chromosome " . $chr,
    $COLORS{black});
 
  ## print "8888: call WriteDKGEToCache <br>";
  return WriteDKToCache($im->png, $chr)
}
 
 
######################################################################

sub DKViewDetail_1 {
 
  my ($base, $org, $chr_in, $pos_in, $start_pos_in, $end_pos_in, $window_size, 
      $filename, $mapped_cache_id, $DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, 
      $AMP_THRESHHOLD, $start_num, $end_num) = @_;
 
  if( $pos_in eq "" and ( $start_pos_in eq "" or $end_pos_in eq "" ) ) {
    print "<b>Please fill both window start and window end<b><br>";
    return;
  }
  my $bin_size = BIN_SIZE;
  my $CHOOSE_WAY = 2;
 
  my ($n);
  my ($tag, $chr, $pos, $strand, $tag_num, $freq, $normal_freq, $window_val);
  my ($last_chr);
  my (@lines, $chr_2_image_id, $high_chr_2_image_id, $low_chr_2_image_id);
  my (@image_map);
  my ($start_pos, $end_pos);
  my (%freq, %max, %window_vals, @dkmap);
  my ($detail_max, $detail_low_max, $detail_high_max);
  my ($detail_data_ref, $del_bounder_ref, $amp_bounder_ref);
  for(my $i=0; $i<@chr_order; $i++) {
    $max{$chr_order[$i]} = 0;
  }
  $detail_max = 0;

  my (%chr_2_id);

  if ($window_size % 2 != 0) {
    $window_size++;
  }
  my $half_window = $window_size / 2;

  my $file; 
  if( $mapped_cache_id >= 100000 ) {
    $file = CACHE_DK_EXIST_ROOT . "DK.$mapped_cache_id.$chr_in"; 
  }
  else {
    $file = CACHE_ROOT . "DK.$mapped_cache_id.$chr_in";
  }
  open(IN, "$file") or die "Can't open $file, the cache file $file expired";
  while (<IN>) {
    chop;
    my ($raw_freq, $normalized_freq) = split /\t/, $_;
    push @{ $freq{$chr_in} }, $normalized_freq;
  }
  close (IN);

  my %n_virtual_tags_per_chr;
  $n_virtual_tags_per_chr{$chr_in} = @{ $freq{$chr_in} };

  for (my $tag_num = 0; $tag_num < @{ $freq{$chr_in} }; $tag_num++) {
    $window_value{$chr_in}[$tag_num] = sprintf("%.2f",
        ComputeWindow($chr_in, $tag_num,
        $half_window, \%n_virtual_tags_per_chr, $window_size, \%freq));
  }

  Do_whole_window_info_data( $chr_in, $bin_size, $CHOOSE_WAY, $filename, 
                             $start_num, $end_num, \@dkmap );

  ($detail_max, $start_pos_in, $end_pos_in, $detail_data_ref, 
                               $del_bounder_ref, $amp_bounder_ref) = 
      Get_detail_max_and_data( $chr_in, $pos_in, $start_pos_in, 
                               $end_pos_in, $CHOOSE_WAY, 
                               $DEL_WIDTH, $DEL_THRESHHOLD,
                               $AMP_WIDTH, $AMP_THRESHHOLD, 
                               $start_num, $end_num, \@dkmap );

  if( $detail_max >= 4 ) {
    $chr_2_image_id = 
       Graph_detail_high($chr_in, $pos_in, $start_pos_in, $end_pos_in,
         $CHOOSE_WAY, $detail_max, $detail_data_ref, $del_bounder_ref, 
         $amp_bounder_ref);
  }
  elsif( $detail_max < 0.5 ) {
    $chr_2_image_id = 
       Graph_detail_low($chr_in, $pos_in, $start_pos_in, $end_pos_in,
         $CHOOSE_WAY, $detail_max, $detail_data_ref, $del_bounder_ref,
         $amp_bounder_ref);
  }
  else {
    $chr_2_image_id = 
       Graph_detail($chr_in, $pos_in, $start_pos_in, $end_pos_in,
         $CHOOSE_WAY, $detail_max, $detail_data_ref, $del_bounder_ref,
         $amp_bounder_ref);
  }
 
  my ($lines_1, $lines_2) =  Make_detail_html($org, $chr_in, $pos_in, 
                               $start_pos_in, $end_pos_in, $window_size,
                               $filename, $mapped_cache_id,
                               $DEL_WIDTH, $DEL_THRESHHOLD, 
                               $AMP_WIDTH, $AMP_THRESHHOLD); 
  push @lines, $lines_1;
  
  push @lines, 
        "<img src=\"DKImage?CACHE=$chr_2_image_id&CHR=$chr_in\" border=0><br>";
 
  my $chrmapname = "chrmap" . $chr_in;
  push @image_map, "<map name=\"$chrmapname\">";
  my $id;
  $id = Graph_chr($org, $chr_in, \@image_map, $pos_in, $start_pos_in, 
                  $end_pos_in,
                  $window_size, $filename,  
                  $mapped_cache_id, $DEL_WIDTH, $DEL_THRESHHOLD, 
                  $AMP_WIDTH, $AMP_THRESHHOLD);

  push @image_map, "</map>";
 
  push @lines, "<img src=\"DKImage?CACHE=$id&CHR=$chr_in\" border=0 usemap=\"#$chrmapname\"><br>";
  push @lines, @image_map;

  push @lines, $lines_2;

  return (join "", @lines);
}
 
######################################################################
sub Do_whole_window_info_data {
  my ($chr_in, $bin_size, $CHOOSE_WAY, $filename, 
      $start_num, $end_num, $dkmap_ref) = @_;
  my ($n, @dkmap, %max);

  my ($db, $sql, $stm);
  $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    exit();
  }
 
  $sql = "select TAG, CHROMOSOME, POS, STRAND, TAGNUM " .
         "from $CGAP_SCHEMA.DKMAP where CHROMOSOME = '$chr_in' " .
         "order by TAGNUM";
 
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
 
  $n = 0;
  while(my ($tag, $chr, $pos, $strand, $tag_num) = $stm->fetchrow_array()) {
    $$dkmap_ref[$n] = (join "\t", $tag, $chr, $pos, $strand, $tag_num);
    push @window_val, $window_value{$chr}[$n];
    push @start, $pos;
    if ($n % $bin_size == 0) {
      DoBin($chr_in, $n, $bin_size, \%max);
    }
    $n++;
  }
 
  $db->disconnect();
 
  if ($n % $bin_size > 0) {
    DoBin($chr_in, $n, $bin_size, \%max);
  }
}

######################################################################
sub Get_detail_max_and_data {
  my ($chr_in, $pos_in, $start_pos_in, $end_pos_in, $CHOOSE_WAY, 
      $DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD,
      $start_num_in, $end_num_in, $dkmap_ref) = @_;

  my @dkmap = @{ $dkmap_ref };
  my ($detail_max, @detail_data);
  my @v;
  ## get $detail_max and @detail_data
  my $m;
  if( $start_num_in ne "" and $end_num_in ne "" ) {
    for (my $n = 0; $n < @dkmap; $n++) {
      my ($tag,$chr,$pos,$strand,$tag_num) = split /\t/, $dkmap[$n];
      if( $tag_num < $start_num_in or $tag_num > $end_num_in ) {
        next;
      }
      my $value = $window_value{$chr_in}[$n];
      if( $tag_num == $start_num_in ) {
        push @detail_data, 
             (join "\t", $chr,$pos,$tag_num,$value);
        if( $value > $detail_max ) {
          $detail_max = $value;
        }
        $m = 0;
      }
      else {
        if ($m % $CHOOSE_WAY == 0) {
          push @detail_data, 
               (join "\t", $chr,$pos,$tag_num,$value);
        }
        if( $value > $detail_max ) {
          $detail_max = $value;
        }
      }
    }
  }
  elsif( $start_pos_in ne "" and $end_pos_in ne "" ) {
    for (my $n = 0; $n < @dkmap; $n++) {
      my ($tag,$chr,$pos,$strand,$tag_num) = split /\t/, $dkmap[$n];
      if( $pos < $start_pos_in or $pos > $end_pos_in ) {
        next;
      }
      my $value = $window_value{$chr_in}[$n];
      if ($n % $CHOOSE_WAY == 0) {
        push @detail_data, (join "\t", $chr,$pos,$tag_num,$value);
      }
      if( $value > $detail_max ) {
        $detail_max = $value;
      }
    }

    my $size = @detail_data;
    if( $size > $DETAIL_MAX ) {
      $DETAIL_WARNING = 1;
      $detail_max = 0;
      my $ratio = $size / $DETAIL_MAX;
      my @tmp_lines;
      if( $ratio < 10 ) {
        my $block = int( $ratio * 10 );
        for ( my $i=0; $i<@detail_data; $i++ ) {
          if( ($i%$block) <= 10 ) { 
            push @tmp_lines, $detail_data[$i];
            my ( $chr,$pos,$tag_num,$value ) = split("\t", $detail_data[$i]);
            if( $value > $detail_max ) {
              $detail_max = $value;
            }
          }
        }
      }
      else {
        my $block = int( $ratio );
        for ( my $i=0; $i<@detail_data; $i++ ) {
          if( $i%$block == 1 ) { 
            push @tmp_lines, $detail_data[$i];
            my ( $chr,$pos,$tag_num,$value ) = split("\t", $detail_data[$i]);
            if( $value > $detail_max ) {
              $detail_max = $value;
            }
          }
        }
      }
      
      undef @detail_data;
      @detail_data = @tmp_lines; 
    }
  }
  elsif ( $pos_in ne "" ) {
    ## my $current_pos = ($pos_in-1)*BIN_SIZE/$CHOOSE_WAY;
    my $current_pos = $pos_in;
    ## my $current_pos = ($pos_in)*BIN_SIZE;
    for (my $n = 0; $n < @dkmap; $n++) {
      my ($tag,$chr,$pos,$strand,$tag_num) = split /\t/, $dkmap[$n];
      if($tag_num >= $current_pos - $DETAIL_WIDTH 
                    and $tag_num <= $current_pos + $DETAIL_WIDTH) {
        my $value = $window_value{$chr_in}[$n];
        if ($n % $CHOOSE_WAY == 0) {
          push @detail_data,
                (join "\t", $chr,$pos,$tag_num,$value);
        }
        if( $value > $detail_max ) {
          $detail_max = $value;
        }
      }
    }
    my ($chr, $pos, $tag_num, $value) = split("\t", $detail_data[0]);
    $start_pos_in = $pos;
    my $size = @detail_data;
    my ($chr, $pos, $tag_num, $value) = split("\t", $detail_data[$size - 1]);
    $end_pos_in = $pos;
  }

  #########

  my ($start_del, $end_del, $start_amp, $end_amp);
  my ($x);
  my (@del_bounder, @amp_bounder);
 
  my $i;
  my $up_limit = @detail_data;
  my $DEL_ZERO_START = 0;
  my $AMP_ZERO_START = 0;

  ## del
  for ($i = 0; $i < @detail_data; $i++) {
    my ($chr, $pos, $tag_num, $x) = split("\t", $detail_data[$i]);
    if ($x <= $DEL_THRESHHOLD) {
      if (! $start_del and $DEL_ZERO_START == 0) {
        $start_del = $i;
        if( $i == 0 ) {
          $DEL_ZERO_START = 1;
        }
      }
      if( $i == $up_limit - 1 ) {
        $end_del = $i;
        push @del_bounder, (join "\t", $start_del, $end_del);
      }
    } else {
      if ($start_del or $DEL_ZERO_START) {
        if ($i-1 - $start_del >= $DEL_WIDTH) {
          $end_del = $i - 1;
          push @del_bounder, (join "\t", $start_del, $end_del);
          if( $start_del == 0 and $DEL_ZERO_START == 1 ) {
            $DEL_ZERO_START = 0;
          }
        }
      }
      $DEL_ZERO_START = 0;
      $start_del = 0;
      $end_del = 0;
    }

    ## amp
    if ($x >= $AMP_THRESHHOLD) {
      if (! $start_amp and $AMP_ZERO_START == 0) {
        $start_amp = $i;
        if( $i == 0 ) {
          $AMP_ZERO_START = 1;
        }
      }
      if( $i == $up_limit - 1 ) {
        $end_amp = $i;
        push @amp_bounder, (join "\t", $start_amp, $end_amp);
      }
    } else {
      if ($start_amp or $AMP_ZERO_START) {
        if ($i-1 - $start_amp >= $AMP_WIDTH) {
          $end_amp = $i;
          push @amp_bounder, (join "\t", $start_amp, $end_amp);
          if( $start_amp == 0 and $AMP_ZERO_START == 1 ) {
            $AMP_ZERO_START = 0;
          }
        }
      }
      $AMP_ZERO_START = 0;
      $start_amp = 0;
      $end_amp = 0;
    }
  }

  #########

  return ($detail_max, $start_pos_in,  $end_pos_in, \@detail_data, 
          \@del_bounder, \@amp_bounder);

}

######################################################################
sub DoBin_detail {
  my ($chr, $n, $bin_size) = @_;
  ## $flag = 1 for low, 2 for normal, 3 for high
 
  my $bn = int($n / $bin_size);
  
  if ($n % $bin_size > 0) {
    $bn++;
  }
  my $s_pos = $start[0];
  my $e_pos = $start[$#start];
  my $mid = int(@window_val / 2);
  my $avg = $window_val[$mid];
  push @{ $binned_data_detail{$chr} }, join("\t",
            $bn,
            $chr,
            $s_pos,
            $e_pos,
            $n - scalar(@window_val) + 1,
            $n,
            $avg
          );

  undef @start;
  undef @end;
  undef @window_val;
}
 
######################################################################
sub Graph_detail {
  my ($chr, $pos, $start_pos_in, $end_pos_in, $CHOOSE_WAY,
      $detail_max, $detail_data_ref, $del_bounder_ref, $amp_bounder_ref) = @_;

  my @graph_area = @{ $detail_data_ref };
  my @del_bounder = @{ $del_bounder_ref };
  my @amp_bounder = @{ $amp_bounder_ref };
  my $scalar = $DETAIL_SCALAR;

use GD;
 
  my $WIDTH = scalar(@graph_area) * $scalar;
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }

  my $high_scale = int($detail_max);
  my $GRAPH_HEIGHT        = 50 + $high_scale * $DETAIL_SCALE;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * $WIDTH; 
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 200;
  my $IMAGE_WIDTH         = $GRAPH_WIDTH  + 150;
  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);
 
  # allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
 
  my %COLORS;
  $COLORS{white}       = $im->colorAllocate(255,255,255);
  $COLORS{black}       = $im->colorAllocate(0,0,0);
  $COLORS{lightgray}   = $im->colorAllocate(240,240,240);
  $COLORS{red}         = $im->colorAllocate(255,0,0);
  $COLORS{lightblue}   = $im->colorAllocate(0,255,255);
  $COLORS{blue}   = $im->colorAllocate(0,0,255);
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+28, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT, 0, $COLORS{black});
  for (my $y0 = $GRAPH_HEIGHT - 50; $y0 >= 0; $y0 = $y0 - $DETAIL_SCALE) {
    my $x0 = 0;
    $im->string(gdSmallFont, $x0, $y0, int( 1 + ($GRAPH_HEIGHT - $y0)/$DETAIL_SCALE), $COLORS{black});
  }
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*BIN_SIZE/$CHOOSE_WAY;
  ## my $current_pos = $pos*BIN_SIZE/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  my %i2value;
  my $total = @graph_area;

  for (my $i = 0; $i < @graph_area; $i++) {

    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$i]);
    my $tmp_pos = $i * $scalar;
    if( ($i) % $SCALE == 0 ) {
      $i2value{$tmp_pos} = $start_pos;
    }
    if( $i == $total - 1 ) {
      if( not defined $i2value{$tmp_pos} ) {
        $i2value{$tmp_pos} = $start_pos;
      }
    }
    my $x0 = $PIX_PER_INTERVAL * ($i * $scalar) ;
    ## my $x1 = $PIX_PER_INTERVAL * ($i + $scalar);

    my $y0;
    if( $value <= 1 ) {
      $y0 = $GRAPH_HEIGHT - int(50 * $value);
    }
    else {
      $y0 = $GRAPH_HEIGHT - int(50 + ($value-1) * $DETAIL_SCALE);
    }
    my $y1;
    ## print "8888: $i, $value<br>";
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if (defined $pre_x0 and defined $pre_y0) {
      $im->line (
          $x0+30,
          $y0,
          $pre_x0,
          $pre_y0,
          $COLORS{red}
      );
    }
    $last_val = $value;
    $pre_x0 = $x0+30;
    $pre_y0 = $y0;
  }

  for (my $i = 0; $i<@del_bounder; $i++) {
    my ($start, $end) = split "\t", $del_bounder[$i];
    if( $start != $end ) {
      $start = $start - 1;
    }
    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$start]);
    my $x0 = $PIX_PER_INTERVAL * ($start * $scalar) + 30 ;
    my $y0 = $GRAPH_HEIGHT;
    my $y1 = $y0 + 90 + $i * 10;
    $im->line($x0, $y0, $x0, $y1, $COLORS{blue});
    $im->string(gdSmallFont, $x0, $y1, $start_pos, $COLORS{black});
 
    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$end]);
    my $x0 = $PIX_PER_INTERVAL * ($end * $scalar) + 30;
    my $y0 = $GRAPH_HEIGHT;
    my $y1 = $y0 + 110 + $i * 10;
    $im->line($x0, $y0, $x0, $y1, $COLORS{blue});
    $im->string(gdSmallFont, $x0, $y1, $start_pos, $COLORS{black});
  
  }

  my $x0 = 0 + 30;
  my $x1 = $GRAPH_WIDTH + 30;
  my $y0 = $GRAPH_HEIGHT - int(50 * 1);
  my $y1 = $y0;
  $im->line($x0, $y0, $x1, $y1, $COLORS{white});

  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  for my $i (sort numerically keys %i2value) {
    $im->stringUp(gdSmallFont, $i+20, $GRAPH_HEIGHT+80, int($i2value{$i}), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($i+30, $y0, $i+30, $y1, $COLORS{black});
  }

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return $cache_id;
}

######################################################################
sub Graph_detail_high {

  my ($chr, $pos, $start_pos_in, $end_pos_in, $CHOOSE_WAY, 
      $max, $detail_data_ref, $del_bounder_ref, $amp_bounder_ref) = @_;

  my @graph_area = @{ $detail_data_ref };
  my @del_bounder = @{ $del_bounder_ref };
  my @amp_bounder = @{ $amp_bounder_ref };
  my $scalar = $DETAIL_SCALAR;
  my $length = @graph_area - 1;
  if( $length <= 20 ) {
    $scalar = $DETAIL_SCALAR * 6;
  }
  elsif( $length <= 40 ) {
    $scalar = $DETAIL_SCALAR * 3;
  }

use GD;
 
  my $WIDTH = scalar(@graph_area) * $scalar;
  if( $length <= 20 ) {
    $WIDTH = scalar(@graph_area) * $scalar - 10;
  }
  elsif( $length <= 40 ) {
    $WIDTH = scalar(@graph_area) * $scalar - 4;
  }
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  ## my $GRAPH_HEIGHT        = 50 + 100 * ( int($detail_max) + 2 );
  my $GRAPH_HEIGHT        = 200;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * $WIDTH; 
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 200;
  my $IMAGE_WIDTH         = $GRAPH_WIDTH  + 150;
  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);
 
  # allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
 
  my %COLORS;
  $COLORS{white}       = $im->colorAllocate(255,255,255);
  $COLORS{black}       = $im->colorAllocate(0,0,0);
  $COLORS{lightgray}   = $im->colorAllocate(240,240,240);
  $COLORS{red}         = $im->colorAllocate(255,0,0);
  $COLORS{lightblue}   = $im->colorAllocate(0,255,255);
  $COLORS{blue}   = $im->colorAllocate(0,0,255);
 
  $im->filledRectangle (
     0+30, 0, $GRAPH_WIDTH+28, $GRAPH_HEIGHT,
     $COLORS{black}
  );

  my $x0 = $GRAPH_WIDTH+35;
  my $y0;
  if( int($max) + 1 <= 14 ) {
    $y0 = $GRAPH_HEIGHT - int(50 * ($max/int($max + 1)) * 4);
  }
  else {
    $y0 = $GRAPH_HEIGHT - int(50 * ($max/($max + 1)) * 4);
  }
  $im->string(gdSmallFont, $x0, $y0, $max, $COLORS{red});

  my $increase;
  my $count = 0;
  if( int($max) + 1 <= 14 ) {
    $increase = 1;
    my $y_scale = $GRAPH_HEIGHT/(int($max) + 1);
    for (my $y0 = $GRAPH_HEIGHT; $y0 >= -0.1; $y0 = $y0 - $y_scale) {
      ## print "8888: $y0 <br>";
      my $value = $count*$increase;
      my $x0 = 0;
      $im->line ( $x0+25, $y0, $x0+30, $y0, $COLORS{red});
      my $int_value = sprintf "%d", $value + .05;
      $im->string(gdSmallFont, $x0, $y0, $int_value, $COLORS{red});
      $count++;
    }
  }
  else {
    $increase = (int($max) + 1)/10;
    for (my $y0 = $GRAPH_HEIGHT; $y0 >= 0; $y0 = $y0 - 20) {
      my $value = $count*$increase;
      my $x0 = 0;
      $im->line ( $x0+25, $y0, $x0+30, $y0, $COLORS{red});
      my $int_value = sprintf "%d", $value + .05;
      $im->string(gdSmallFont, $x0, $y0, $int_value, $COLORS{red});
      $count++;
    }
  }
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*BIN_SIZE/$CHOOSE_WAY;
  ## my $current_pos = $pos*BIN_SIZE/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  my %i2value;
  my $total = @graph_area;

  for (my $i = 0; $i < @graph_area; $i++) {

    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$i]);
    my $tmp_pos = $i * $scalar;
    if( ($i) % $SCALE == 0 ) {
      $i2value{$tmp_pos} = $start_pos;
    }
    if( $i == $total - 1 ) {
      if( not defined $i2value{$tmp_pos} ) {
        $i2value{$tmp_pos} = $start_pos; 
      }
    }
    my $x0 = $PIX_PER_INTERVAL * ($i * $scalar) ;
    ## my $x1 = $PIX_PER_INTERVAL * ($i + $scalar);
    my $y0;
    if( int($max) + 1 < 14 ) {
      $y0 = $GRAPH_HEIGHT - int(50 * ($last_val/int($max + 1)) * 4);
    }
    else {
      $y0 = $GRAPH_HEIGHT - int(50 * ($last_val/($max + 1)) * 4);
    }
    my $y1;
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if (defined $pre_x0 and defined $pre_y0) {
      $im->line (
          $x0+30,
          $y0,
          $pre_x0,
          $pre_y0,
          $COLORS{red}
      );
    }
    $last_val = $value;
    $pre_x0 = $x0+30;
    $pre_y0 = $y0;
  }

  for (my $i = 0; $i<@del_bounder; $i++) {
    my ($start, $end) = split "\t", $del_bounder[$i]; 
    ## if( $start == $end ) {
    ##   $start = $start - 1;
    ## }
    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$start]);
    my $x0 = $PIX_PER_INTERVAL * ($start * $scalar) + 30 ;
    my $y0 = $GRAPH_HEIGHT;
    my $y1 = $y0 + 90 + $i * 10;
    $im->line($x0, $y0, $x0, $y1, $COLORS{blue});
    $im->string(gdSmallFont, $x0, $y1, $start_pos, $COLORS{black});
 
    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$end]);
    my $x0 = $PIX_PER_INTERVAL * ($end * $scalar) + 30;
    my $y0 = $GRAPH_HEIGHT;
    my $y1 = $y0 + 110 + $i * 10;
    $im->line($x0, $y0, $x0, $y1, $COLORS{blue});
    $im->string(gdSmallFont, $x0, $y1, $start_pos, $COLORS{black});
   
  }

  for (my $i = 0; $i<@amp_bounder; $i++) {
    my ($start, $end) = split "\t", $amp_bounder[$i];
    ## if( $start == $end ) {
    ##   $start = $start - 1;
    ## }
    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$start]);
    my $x0 = $PIX_PER_INTERVAL * ($start * $scalar) + 30;
    my $y0 = $GRAPH_HEIGHT;
    my $y1 = $y0 + 100 + $i * 10;
    $im->line($x0, $y0, $x0, $y1, $COLORS{red});
    $im->string(gdSmallFont, $x0, $y1, $start_pos, $COLORS{black});

    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$end]);
    my $x0 = $PIX_PER_INTERVAL * ($end * $scalar) + 30;
    my $y0 = $GRAPH_HEIGHT;
    my $y1 = $y0 + 120 + $i * 10;
    $im->line($x0, $y0, $x0, $y1, $COLORS{red});
    $im->string(gdSmallFont, $x0, $y1, $start_pos, $COLORS{black});
    
  }
  ## my $x0 = $HALF_WIDTH + 30;
  ## my $x1 = $x0;
  ## my $y0 = $GRAPH_HEIGHT - $mid_value;
  ## my $y0 = $mid_value;
  ## my $y1 = $GRAPH_HEIGHT;
  ## $im->line($x0, $y0, $x1, $y1, $COLORS{lightblue});

  my $y1;
  my $increase = ($total) / 10;
  my $count = 0;

  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  for my $i (sort numerically keys %i2value) {
    $im->stringUp(gdSmallFont, $i+20, $GRAPH_HEIGHT+80, int($i2value{$i}), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($i+30, $y0, $i+30, $y1, $COLORS{black});
  }

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return $cache_id;
}


######################################################################
sub Graph_chr {
  my ($org, $chr, $image_map_ref, $pos_in, $start_pos_in, $end_pos_in,
      $window_size, $filename, $mapped_cache_id, 
      $DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD) = @_;

use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  my $GRAPH_HEIGHT        = 200;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * @{ $binned_data{$chr} };
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 30;
  my $IMAGE_WIDTH         = $GRAPH_WIDTH  + 200;
  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);
 
  # allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
 
  my %COLORS;
  $COLORS{white}       = $im->colorAllocate(255,255,255);
  $COLORS{black}       = $im->colorAllocate(0,0,0);
  $COLORS{lightgray}   = $im->colorAllocate(240,240,240);
  $COLORS{red}         = $im->colorAllocate(255,0,0);
  $COLORS{blue}        = $im->colorAllocate(0,0,255);
  $COLORS{lightblue}   = $im->colorAllocate(0,255,255);

  my $color;
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+28, $GRAPH_HEIGHT,
    $COLORS{black}
  );
  for (my $y0 = $GRAPH_HEIGHT; $y0 >= 0; $y0 = $y0 - 50) {
    my $x0 = 0;
    $im->string(gdSmallFont, $x0, $y0, int(($GRAPH_HEIGHT - $y0)/50), $COLORS{black});
  }
 
  my $last_val;
  my $mark_flag = 0;
  for (my $i = 1; $i < @{ $binned_data{$chr} }; $i++ ) {
    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data{$chr}[$i]);
    my $x0 = $PIX_PER_INTERVAL * ($i - 1);
    my $x1 = $PIX_PER_INTERVAL * $i;
    my $y0 = $GRAPH_HEIGHT - int(50 * $last_val);
    my $y1;
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( $start_pos >= $start_pos_in and $start_pos <= $end_pos_in  ) {
      $mark_flag = 1;
      $color = $COLORS{lightblue};
      $y1 = $GRAPH_HEIGHT + 10;
      $im->line (
          $x0+30,
          $y0,
          $x0+30,
          $y1,
          $color
      );
    } 
    elsif( $mark_flag == 0 and $start_pos > $end_pos_in  ) {
      $mark_flag = 1;
      $color = $COLORS{lightblue};
      $y1 = $GRAPH_HEIGHT + 10;
      $im->line (
          $x0+30,
          $y0,
          $x0+30,
          $y1,
          $color
      );
    }
    else {
      $color = $COLORS{red};
      if ($x0 == $x1) {
        $im->line (
            $x0+30,
            $y0,
            $x1+30,
            $y1,
            $color
        );
      } else {
        $im->filledRectangle (
            $x0+30,
            $y0,
            $x1+30,
            $y1,
            $color
        );
      }
    }
    $last_val = $value;
    my $x0_pos = $x0+30;
    my $x1_pos = $x1+30;
    push @{ $image_map_ref },
      "<area shape=rect coords=\"$x0_pos,$y0,$x1_pos,$y1\" " .
      "href=javascript:spawn(\"DKViewDetail?ORG=$org&CHR=$chr&POS=$start_tag&START_POS=&END_POS=&WINDOWSIZE=$window_size&FILENAME=$filename&MAPPED_DATA_CACHE_ID=$mapped_cache_id&DELWIDTH=$DEL_WIDTH&DELTHRESHHOLD=$DEL_THRESHHOLD&AMPWIDTH=$AMP_WIDTH&AMPTHRESHHOLD=$AMP_THRESHHOLD\")>";
  }
  my $x0 = 0 + 30;
  my $x1 = $GRAPH_WIDTH + 30;
  my $y0 = $GRAPH_HEIGHT - int(50 * 1);
  my $y1 = $y0;
  $im->line($x0, $y0, $x1, $y1, $COLORS{white});
  $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+10, "Chromosome " . $chr,
    $COLORS{black});
 
  ## print "8888: call WriteDKGEToCache <br>";
  return WriteDKToCache($im->png, $chr)
}

######################################################################
sub Graph_detail_low {

  my ($chr, $pos, $start_pos_in, $end_pos_in, $CHOOSE_WAY,
      $max, $detail_data_ref, $del_bounder_ref, $amp_bounder_ref) = @_;
 
  my @graph_area = @{ $detail_data_ref };
  my @del_bounder = @{ $del_bounder_ref };
  my @amp_bounder = @{ $amp_bounder_ref };
  my $scalar = $DETAIL_SCALAR;
  my $length = @graph_area - 1;
  if( $length <= 20 ) {
    $scalar = $DETAIL_SCALAR * 6;
  }
  elsif( $length <= 40 ) {
    $scalar = $DETAIL_SCALAR * 3;
  }

use GD;
 
  my $WIDTH = scalar(@graph_area) * $scalar;
  if( $length <= 20 ) {
    $WIDTH = scalar(@graph_area) * $scalar - 10;
  }
  elsif( $length <= 40 ) {
    $WIDTH = scalar(@graph_area) * $scalar - 5;
  }
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }

  my $GRAPH_HEIGHT        = int(400 * $max) + 30;
  ## my $GRAPH_HEIGHT        = 400 + 50;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * $WIDTH; 
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 200;
  my $IMAGE_WIDTH         = $GRAPH_WIDTH  + 150;
  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);
 
  # allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
 
  my %COLORS;
  $COLORS{white}       = $im->colorAllocate(255,255,255);
  $COLORS{black}       = $im->colorAllocate(0,0,0);
  $COLORS{lightgray}   = $im->colorAllocate(240,240,240);
  $COLORS{red}         = $im->colorAllocate(255,0,0);
  $COLORS{lightblue}   = $im->colorAllocate(0,255,255);
  $COLORS{blue}   = $im->colorAllocate(0,0,255);
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+28, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT, 0, $COLORS{black});
  my $x = 0;
  my $y = $GRAPH_HEIGHT - int(400 * $max);
  $im->string(gdSmallFont, 0, $y, $max, $COLORS{black});
  $im->line ( $x+25, $y, $x+30, $y, $COLORS{black});

  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*BIN_SIZE/$CHOOSE_WAY;
  ## my $current_pos = $pos*BIN_SIZE/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  my %i2value;
  my $total = @graph_area;
 
  for (my $i = 0; $i < @graph_area; $i++) {
 
    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$i]);
    my $tmp_pos = $i * $scalar;
    if( ($i) % $SCALE == 0 ) {
      $i2value{$tmp_pos} = $start_pos;
    }
    if( $i == $total - 1 ) {
      if( not defined $i2value{$tmp_pos} ) {
        $i2value{$tmp_pos} = $start_pos;
      }
    }
    my $x0 = $PIX_PER_INTERVAL * ($i * $scalar) ;
    my $y0;
    $y0 = $GRAPH_HEIGHT - int(400 * $value);
    my $y1;
    if (defined $pre_x0 and defined $pre_y0) {
      $im->line (
          $x0+30,
          $y0,
          $pre_x0,
          $pre_y0,
          $COLORS{red}
      );
    }
    $last_val = $value;
    $pre_x0 = $x0+30;
    $pre_y0 = $y0;
  }

  for (my $i = 0; $i<@del_bounder; $i++) {
    my ($start, $end) = split "\t", $del_bounder[$i];
    ## if( $start == $end ) {
    ##   $start = $start - 1;
    ## }
    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$start]);
    my $x0 = $PIX_PER_INTERVAL * ($start * $scalar) + 30 ;
    my $y0 = $GRAPH_HEIGHT;
    my $y1 = $y0 + 90 + $i * 10;
    $im->line($x0, $y0, $x0, $y1, $COLORS{blue});
    $im->string(gdSmallFont, $x0, $y1, $start_pos, $COLORS{black});
 
    my ($chr, $start_pos, $tag_num, $value) = split("\t", $graph_area[$end]);
    my $x0 = $PIX_PER_INTERVAL * ($end * $scalar) + 30;
    my $y0 = $GRAPH_HEIGHT;
    my $y1 = $y0 + 110 + $i * 10;
    $im->line($x0, $y0, $x0, $y1, $COLORS{blue});
    $im->string(gdSmallFont, $x0, $y1, $start_pos, $COLORS{black});
  
  }

  my $x0 = 0 + 30;
  my $x1 = $GRAPH_WIDTH + 30;
  my $y0 = $GRAPH_HEIGHT - 400;
  my $y1 = $y0;
  $im->line($x0, $y0, $x1, $y1, $COLORS{white});


  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;

  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  for my $i (sort numerically keys %i2value) {
    $im->stringUp(gdSmallFont, $i+20, $GRAPH_HEIGHT+80, int($i2value{$i}), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($i+30, $y0, $i+30, $y1, $COLORS{black});
  }

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  ########## need to fix
  return $cache_id;
}

######################################################################
sub WriteDKDataToCache {
  my ($data) = @_;
 
  my ($dk_cache_id, $filename) = $dk_cache->MakeCacheFile();
  if ($dk_cache_id != $CACHE_FAIL) {
    ## print "8888 id: $dk_cache_id \n";
    ## print "8888 name: $filename \n";
    if (open(SOUT, ">$filename")) {
      print SOUT $data;
      close SOUT;
      chmod 0666, $filename;
    } else {
      $dk_cache_id = 0;
    }
  }
  return $dk_cache_id;
}
 
######################################################################
sub GetDKDataFromCache_1 {
  my ($base, $cache_id) = @_;
 
  $BASE = $base;
 
  return ReadDKDataFromCache($cache_id);
}
 
######################################################################
sub ReadDKDataFromCache {
  my ($cache_id) = @_;
 
  my ($s, @data);
  my $cache_pointer;
  if( $cache_id <100000 ) {
    $cache_pointer = $dk_cache;
  }
  else {
    $cache_pointer = $dk_exist_cache;
  }
 
  if ($cache_pointer->FindCacheFile($cache_id) eq $CACHE_FAIL) {
    return "Cache expired";
  }
  my $filename = $cache_pointer->FindCacheFile($cache_id);
  ## print "$filename";
  open(IN, "$filename") or die "Can't open $filename.";
  ## while (read IN, $s, 16384) {
  ##   push @data, $s;
  ## }
  while (<IN>) {
    push @data, $_;
  }
  close (IN);
  return join("", @data);
 
}
 
######################################################################
sub WriteDKToCache {
  my ($data, $chr) = @_;
 
  my ($dk_cache_id, $filename) = $dk_cache->MakeDKCacheFile($chr);
  if ($dk_cache_id != $CACHE_FAIL) {
    ## print "8888 id: $dk_cache_id \n";
    ## print "8888 name: $filename \n";
    if (open(SOUT, ">$filename")) {
      print SOUT $data;
      close SOUT;
      chmod 0666, $filename;
    } else {
      $dk_cache_id = 0;
    }
  }
  return $dk_cache_id;
}
 
######################################################################
sub GetDKFromCache_1 {
  my ($base, $cache_id, $chr) = @_;
 
  $BASE = $base;
 
  return ReadDKFromCache($cache_id, $chr);
}
 
######################################################################
sub GetDKFromQueryCache_1 {
  my ($base, $cache_id, $chr) = @_;
 
  $BASE = $base;
 
  return ReadDKFromQueryCache($cache_id, $chr);
}
 
######################################################################
sub ReadDKFromCache {
  my ($cache_id, $chr) = @_;
 
  my ($s, @data);
 
  if ($dk_cache->FindDKCacheFile($cache_id, $chr) eq $CACHE_FAIL) {
    return "Cache expired";
  }
  my $filename = $dk_cache->FindDKCacheFile($cache_id, $chr);
  ## print "$filename";
  open(IN, "$filename") or die "Can't open $filename.";
  while (read IN, $s, 16384) {
    push @data, $s;
  }
  close (IN);
  return join("", @data);
 
}
 
######################################################################
sub ReadDKFromQueryCache {
  my ($cache_id, $chr) = @_;
 
  my ($s, @data);
 
  if ($dk_exist_cache->FindDKCacheFile($cache_id, $chr) eq $CACHE_FAIL) {
    return "Cache expired";
  }
  my $filename = $dk_exist_cache->FindDKCacheFile($cache_id, $chr);
  ## print "$filename";
  open(IN, "$filename") or die "Can't open $filename.";
  while (read IN, $s, 16384) {
    push @data, $s;
  }
  close (IN);
  return join("", @data);
 
}
 
######################################################################
sub Thousands {
  my ($x) = @_;
 
  my ($rem, $str);
  while ($x > 0) {
    $rem = sprintf("%3.3d", $x % 1000);
    $str = $str ? "$rem,$str" : "$rem";
    $x = int($x / 1000);
  }
  $str =~ s/^0+//;
  return $str;
}
 
######################################################################
sub DividerBar {
  my ($text) = @_;
 
  return "<table width=100% cellpadding=4>" .
      "<tr bgcolor=\"#666699\"><td><font color=\"white\"><b>" .
      $text .
      "</b></font></td></tr></table>";
}

######################################################################

sub Hunt_anomalies {
  my ($DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD) = @_;
  
  ## input is 8 columns:
  ##   tag
  ##   chromosome
  ##   bp
  ##   strand
  ##   tag ordinal
  ##   raw freq
  ##   normalized freq
  ##   smoothed value
  
  my ($inp_f, $out_f);
  
  my $DEL_AREA = $DEL_WIDTH * $DEL_THRESHHOLD;
  my $AMP_AREA = $AMP_WIDTH * $AMP_THRESHHOLD;
  
  Analyze($DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD);
  
  for my $chr (@chr_order) {
    for my $start (sort numerically keys %{ $result{$chr} }) {
      for my $end (sort numerically keys %{ $result{$chr}{$start} }) {
        my $what = $result{$chr}{$start}{$end};
        if( $what eq "amp" ) {
          $amp{$chr}{$start} = $end; 
        }
        elsif( $what eq "del" ) {
          $del{$chr}{$start} = $end;
        }
      }
    }
  }
}

######################################################################
sub AnalyzeChr {

  my ($chr, $v, $del_width, $del_threshhold, $amp_width, $amp_threshhold) = @_;

  ## version that does not take area; just look for continuous
  ## stretch of smoothed tags where each smoothed tag is > threshhold
 
  my ($start_del, $start_amp);
  my ($x);

  ## use zero base for arrays, adjust to tag number

  my $i;
  my ($MAX, $MIN);
  my $up_limit = @{ $v };
  for ($i = 0; $i < @{ $v }; $i++) {
    $x = $$v[$i];

    if ($x <= $del_threshhold) {
      if (! $start_del) {
        $start_del = $i;
        $MIN = $x; 
      }
      else {
        if( $x < $MIN ) {
          $MIN = $x;
        }
      }
      if( $i == $up_limit - 1 ) {
        $result{$chr}{$start_del+1}{$i-1} = "del";    ## adjust index
        if( $MIN == -0.00 ) {
          $MIN = "0.00";
        } 
        $DEL_RATIO{$chr}{$start_del+1} = $MIN;
        $MIN = 100000000000000;
      }
    } else {
      if ($start_del) {
        if ($i-1 - $start_del >= $del_width) {
          if ( ($i-1) > ($start_del+1) ) {
            $result{$chr}{$start_del+1}{$i-1} = "del";    ## adjust index
            if( $MIN == -0.00 ) {
              $MIN = "0.00";
            }
            $DEL_RATIO{$chr}{$start_del+1} = $MIN;
            $MIN = 100000000000000;
          }
        }
      }
      $start_del = 0;
    }

    if ($x >= $amp_threshhold) {
      if (! $start_amp) {
        $start_amp = $i;
        $MAX = $x; 
      }
      else {
        if( $x > $MAX ) {
          $MAX = $x;
        } 
      }
      if( $i == $up_limit - 1 ) {
        $result{$chr}{$start_amp}{$i} = "amp";    ## adjust index
        $AMP_RATIO{$chr}{$start_amp} = $MAX;
        $MAX = 0;
      }
    } else {
      if ($start_amp) {
        if ($i-1 - $start_amp >= $amp_width) {
          $result{$chr}{$start_amp}{$i} = "amp";    ## adjust index
          $AMP_RATIO{$chr}{$start_amp} = $MAX;
          $MAX = 0;
        }
      }
      $start_amp = 0;
    }
  }
  if ($start_del && $i-1 - $start_del >= $del_width) {
    $result{$chr}{$start_del+1}{$i} = "del";    ## adjust index
  }
  if ($start_amp && $i-1 - $start_amp >= $amp_width) {
    $result{$chr}{$start_amp+1}{$i} = "amp";    ## adjust index
  }
}

######################################################################
sub Analyze {
  my ($DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, $AMP_THRESHHOLD) = @_;
  for my $chr (keys %data) {
    AnalyzeChr($chr, $data{$chr}, $DEL_WIDTH, $DEL_THRESHHOLD, $AMP_WIDTH, 
                                  $AMP_THRESHHOLD);
  }
}

######################################################################
sub ReadData {
  ## my ($smoothed_cache_id) = @_;
  my (%freq, %chr_2_id);
 
  my ($chromo, $start_pos, $end_pos);
  my $need_tag_num = 1;
  get_data_from_dkmap($chromo, $start_pos, $end_pos, $need_tag_num);
  open (IN, $map_f) or die "Can't open $map_f";
  while(<IN>) {
    chop;
    my ($tag, $chr, $pos, $strand, $tag_num) = split "\t", $_;
    push @{ $dkmap{$chr} }, $_;
  }
  close (IN);
 
  for my $chr (@chr_order) {
    for ( my $i=0; $i<@{ $window_value{$chr} }; $i++ ) {
      chop;
      my ($tag, $chr, $bp, $strand, $ord) = split /\t/, $dkmap{$chr}[$i];
      $data{$chr}[$ord] = @{ $window_value{$chr} }[$i];
      $ord2bp{$chr}{$ord} = $bp;
      ## $ord2num{$chr}{$ord} = $ord;
    }
  }
  undef %dkmap;
  undef %window_value;
}

######################################################################
sub amp_area {
  my ($chr, $start_tag, $end_tag) = @_;
  for my $start (sort numerically keys %{$amp{$chr}}) {
    if( $start_tag >= $start ) {
      if( $end_tag <= $amp{$chr}{$start} ) {
      ## if( $start_tag <= $amp{$chr}{$start} ) {
        return 1;
      }
    }
  }
  return "";
}

######################################################################
sub del_area {
  my ($chr, $start_tag, $end_tag) = @_;
  for my $start (sort numerically keys %{$del{$chr}}) {
    if( $start_tag >= $start ) {
      if( $end_tag <= $del{$chr}{$start} ) {
      ## if( $start_tag <= $del{$chr}{$start} ) {
        return 1;
      }
    }
  }
  return "";
}

######################################################################
sub get_data_from_dkmap_file {
  open (IN, $map_f) or die "Can't open $map_f";
  while(<IN>) {
    chop;
    my ($tag, $chr, $pos, $strand, $tag_num) = split "\t", $_;
    push @{ $dkmap{$chr} }, join ("\t", $tag, $chr, $pos, $strand);
  }
  close (IN);
}

######################################################################
sub get_data_from_dkmap {
  my ($chr, $start_pos, $end_pos, $need_tag_num) = @_;

  my ($db, $sql, $stm);
  $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    exit();
  }
 
  if( $chr eq "" ) {
    $sql = "select TAG, CHROMOSOME, POS, STRAND, TAGNUM " .
           "from $CGAP_SCHEMA.DKMAP order by CHROMOSOME, TAGNUM";
  }
  elsif( $start_pos eq "" ) {
    $sql = "select TAG, CHROMOSOME, POS, STRAND, TAGNUM " .
           "from $CGAP_SCHEMA.DKMAP where CHROMOSOME = '$chr' " .
           "order by TAGNUM";
  }
  else {
    $sql = "select TAG, CHROMOSOME, POS, STRAND, TAGNUM " .
           "from $CGAP_SCHEMA.DKMAP where CHROMOSOME = '$chr' " .
           "and POS >= $start_pos and POS <= $end_pos oorder by TAGNUM";
  }
  
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
  while(my ($tag, $chr, $pos, $strand, $tag_num) = $stm->fetchrow_array()) {
    if( $need_tag_num == 1 ) {
      push @{ $dkmap{$chr} }, join ("\t", $tag, $chr, $pos, $strand, $tag_num);
    }
    else {
      push @{ $dkmap{$chr} }, join ("\t", $tag, $chr, $pos, $strand);
    }
  }
 
  $db->disconnect();
}

######################################################################
sub Make_Display_amp_del_page {   
  my ($org, $smoothed_cache_id, $bin_size, $window_size,
      $mapped_cache_id, $DEL_WIDTH, $DEL_THRESHHOLD,
      $AMP_WIDTH, $AMP_THRESHHOLD, $filename) = @_; 

  my $output = 
       "<br><a href=javascript:spawn(\"/SAGE/DKView_All?ORG=Hs&MAPPED_DATA_CACHE_ID=$mapped_cache_id&SMOOTHED_CACHE_ID=$smoothed_cache_id&WINDOWSIZE=$window_size&FILENAME=$filename&DELWIDTH=$DEL_WIDTH&DELTHRESHHOLD=$DEL_THRESHHOLD&AMPWIDTH=$AMP_WIDTH&AMPTHRESHHOLD=$AMP_THRESHHOLD\")>Display plots for all chromosomes</a><br><br>";
        
  $output = $output .
    "<b>Amplification Info:<b><br>" .
    "<table border=\"1\" width=100% cellpadding=2>" .
    "<tr bgcolor=\"#666699\">" .
    "<td width=8%><font color=\"white\"><b>Chromosome</b></font></td>" .
    "<td width=12%><font color=\"white\"><b>Maximum Tag Ratio</b></font></td>" .
    "<td width=12%><font color=\"white\"><b>Amplification Size</b></font></td>" .
    "<td width=12%><font color=\"white\"><b>Start Tag Number</b></font></td>" .
    "<td width=12%><font color=\"white\"><b>End Tag Number</b></font></td>" .
    "<td width=12%><font color=\"white\"><b>Start Position</b></font></td>" .
    "<td width=12%><font color=\"white\"><b>End Position</b></font></td>" .
    "<td width=9%><font color=\"white\"><b>Detail DKView</b></font></td>" .
    "<td width=9%><font color=\"white\"><b>UCSC</b></font></td>" .
    "<td width=9%><font color=\"white\"><b>Download</b></font></td>" .
    "</tr>";

  my $sign = "UCSC";
  for my $chr (@chr_order) {
    my $chr_for_url = "chr" . $chr;
    for my $start_amp ( sort numerically keys %{$amp{$chr}} ) {
      my @lines;
      ## my $start_pos = smooth_data($ord2bp{$chr}{$start_amp});
      ## my $end_pos = smooth_data($ord2bp{$chr}{$amp{$chr}{$start_amp}});
      my $start_pos = $ord2bp{$chr}{$start_amp};
      my $end_pos = $ord2bp{$chr}{$amp{$chr}{$start_amp}};
      my $size = $end_pos - $start_pos;
      push @lines, "<tr>";
      push @lines, "<td width=9%>$chr</td>";
      push @lines, "<td width=12%>$AMP_RATIO{$chr}{$start_amp}</td>"; 
      push @lines, "<td width=12%>$size</td>"; 
      push @lines, "<td width=12%>$start_amp</td>"; 
      push @lines, "<td width=12%>$amp{$chr}{$start_amp}</td>"; 
      push @lines, "<td width=12%>$start_pos</td>"; 
      push @lines, "<td width=12%>$end_pos</td>"; 
      my $view_highperlink;
      if( $size == 0 ) {
        $view_highperlink = "View"; 
      }
      else {
        $view_highperlink = "<a href=javascript:spawn(\"" .
          "DKViewDetail?ORG=$org&CHR=$chr&POS=&START_POS=$start_pos" .
          "&END_POS=$end_pos&WINDOWSIZE=$window_size&" .
          "FILENAME=$filename&MAPPED_DATA_CACHE_ID=$mapped_cache_id" .
          "&DELWIDTH=$DEL_WIDTH&DELTHRESHHOLD=$DEL_THRESHHOLD" .
          "&AMPWIDTH=$AMP_WIDTH&AMPTHRESHHOLD=$AMP_THRESHHOLD" .
          "&START_NUM=$start_amp&END_NUM=$amp{$chr}{$start_amp}\")>View</a>"; 
      }
      push @lines, "<td width=9%>$view_highperlink</td>"; 
      my $highperlink = "<a href=javascript:spawn(\"" .
        "http://genome.ucsc.edu/cgi-bin/hgTracks?clade=vertebrate" .
        "&org=$org&db=$UCSC_DB&position=$chr_for_url:$start_pos-$end_pos" .
        "&pix=620\")>$sign</a>";
      push @lines, "<td width=9%>$highperlink</td>"; 
      my $download_highperlink =
        "<a href=javascript:spawn(\"/SAGE/DKRegionDownload?ORG=Hs&CHR=$chr&MAPPED_DATA_CACHE_ID=$mapped_cache_id&START_POS=$start_pos&END_POS=$end_pos&FILENAME=$filename\")>Download</a>";
      push @lines, "<td width=9%>$download_highperlink</td>"; 
      push @lines, "</tr>";
      $output = $output . (join "", @lines) . "\n";
    }
  }

   
  $output = $output . "</table><br><br><br>";

  $output = $output .
    "<b>Deletion Info:<b><br>" .
    "<table border=\"1\" width=100% cellpadding=2>" .
    "<tr bgcolor=\"#666699\">" .
    "<td width=9%><font color=\"white\"><b>Chromosome</b></font></td>" .
    "<td width=12%><font color=\"white\"><b>Maximum Tag Ratio</b></font></td>" .
    "<td width=12%><font color=\"white\"><b>Deletion Size</b></font></td>" .
    "<td width=18%><font color=\"white\"><b>Start Tag Number</b></font></td>" .
    "<td width=18%><font color=\"white\"><b>End Tag Number</b></font></td>" .
    "<td width=14%><font color=\"white\"><b>Start Position</b></font></td>" .
    "<td width=14%><font color=\"white\"><b>End Position</b></font></td>" .
    "<td width=9%><font color=\"white\"><b>Detail DKView</b></font></td>" .
    "<td width=9%><font color=\"white\"><b>UCSC</b></font></td>" .
    "<td width=9%><font color=\"white\"><b>Download</b></font></td>" .
    "</tr>";
   
  for my $chr (@chr_order) {
    my $chr_for_url = "chr" . $chr;
    for my $start_del ( sort numerically keys %{$del{$chr}} ) {
      my @lines;
      ## my $start_pos = smooth_data($ord2bp{$chr}{$start_del});
      ## my $end_pos = smooth_data($ord2bp{$chr}{$del{$chr}{$start_del}});
      my $start_pos = $ord2bp{$chr}{$start_del};
      my $end_pos = $ord2bp{$chr}{$del{$chr}{$start_del}};
      if( not defined $ord2bp{$chr}{$del{$chr}{$start_del}} ) {
        $end_pos = $ord2bp{$chr}{$del{$chr}{$start_del} - 1};
      } 
      else {
        $end_pos = $ord2bp{$chr}{$del{$chr}{$start_del}};
      }
      my $size = $end_pos - $start_pos;
      push @lines, "<tr>";
      push @lines, "<td width=9%>$chr</td>";
      push @lines, "<td width=12%>$DEL_RATIO{$chr}{$start_del}</td>"; 
      push @lines, "<td width=12%>$size</td>"; 
      push @lines, "<td width=12%>$start_del</td>"; 
      push @lines, "<td width=12%>$del{$chr}{$start_del}</td>"; 
      push @lines, "<td width=12%>$start_pos</td>"; 
      push @lines, "<td width=12%>$end_pos</td>"; 
      my $view_highperlink;
      if( $size == 0 ) {
        $view_highperlink = "View"; 
      }
      else {
        $view_highperlink = "<a href=javascript:spawn(\"" .
          "DKViewDetail?ORG=$org&CHR=$chr&POS=&START_POS=$start_pos" .
          "&END_POS=$end_pos&WINDOWSIZE=$window_size&" .
          "FILENAME=$filename&MAPPED_DATA_CACHE_ID=$mapped_cache_id" .
          "&DELWIDTH=$DEL_WIDTH&DELTHRESHHOLD=$DEL_THRESHHOLD" .
          "&AMPWIDTH=$AMP_WIDTH&AMPTHRESHHOLD=$AMP_THRESHHOLD" .
          "&START_NUM=$start_del&END_NUM=$del{$chr}{$start_del}\")>View</a>"; 
      }
      push @lines, "<td width=9%>$view_highperlink</td>"; 
      my $highperlink = "<p><a href=javascript:spawn(\"" .
          "http://genome.ucsc.edu/cgi-bin/hgTracks?clade=vertebrate" .
          "&org=$org&db=$UCSC_DB&position=$chr_for_url:$start_pos-$end_pos" .
          "&pix=620\")>$sign</a>";
      push @lines, "<td width=9%>$highperlink</td>"; 
      my $download_highperlink =
        "<p><a href=javascript:spawn(\"/SAGE/DKRegionDownload?ORG=Hs&CHR=$chr&MAPPED_DATA_CACHE_ID=$mapped_cache_id&START_POS=$start_pos&END_POS=$end_pos&FILENAME=$filename\")>Download</a>";
      push @lines, "<td width=9%>$download_highperlink</td>"; 
      push @lines, "</tr>";
      $output = $output . (join "", @lines) . "\n";
    }
  }

   
  $output = $output . "</table>";

  return $output;

}

######################################################################
sub Make_detail_html {   
  
  my ($org, $chr_in, $pos_in, $start_pos_in, $end_pos_in, $window_size,
      $filename, $mapped_data_cache_id, $DEL_WIDTH, $DEL_THRESHHOLD,  
      $AMP_WIDTH, $AMP_THRESHHOLD) = @_;
  my ($lines_1, $lines_2);

  ## if( $DETAIL_WARNING == 1 ) {
  ##   $lines = "<b>You chose too big width, which is beyond the allowed window width</b><br><br>";
  ## }

  my $sign = "UCSC browser.";
  my $chr_for_url = "chr" . $chr_in;
  my $highperlink = "<p><a href=javascript:spawn(\"" .
          "http://genome.ucsc.edu/cgi-bin/hgTracks?clade=vertebrate" .
          "&org=$ORGANISM_NAME{$org}&db=$UCSC_DB" .
          "&position=$chr_for_url:$start_pos_in-$end_pos_in" .
          "&pix=620\")>$sign</a><br><br>";

  $lines_1 = $lines_1 . $highperlink;

  my $download_highperlink =
      "<p><a href=javascript:spawn(\"/SAGE/DKRegionDownload?ORG=$org&CHR=$chr_in&MAPPED_DATA_CACHE_ID=$mapped_data_cache_id&START_POS=$start_pos_in&END_POS=$end_pos_in&FILENAME=$filename\")>Download mapped tags for region</a><br><br>";

  $lines_1 = $lines_1 . $download_highperlink;

  ## my $file_name;
  ## push @lines, "File name: $filename<br>";
  my $window_size_for_html = "Window size: $window_size <br>";
  $lines_1 = $lines_1 . $window_size_for_html;
  ## $lines_1 = $lines_1 . "Amplification width (tags): $AMP_WIDTH<br>";
  $lines_1 = $lines_1 . "Amplification fold change: $AMP_THRESHHOLD<br>";
  ## $lines_1 = $lines_1 . "Deletion width (tags): $DEL_WIDTH<br>";
  $lines_1 = $lines_1 . "Deletion fold change: $DEL_THRESHHOLD<br><br><br>";

  $lines_2 = $lines_2 .
    "<form name=\"dkform\" action=\"DKViewDetail\") method=post target=_blank>\n" .
    "<input type=\"hidden\" name=\"MAPPED_DATA_CACHE_ID\" value=$mapped_data_cache_id>\n" .
    "<input type=\"hidden\" name=\"FILENAME\" value=$filename>\n" .
    "<input type=\"hidden\" name=\"ORG\" value=$org>\n" .
    "<input type=\"hidden\" name=\"CHR\" value=$chr_in>\n" .
    "<input type=\"hidden\" name=\"DELWIDTH\" value=$DEL_WIDTH>\n" .
    "<input type=\"hidden\" name=\"DELTHRESHHOLD\" value=$DEL_THRESHHOLD>\n" .
    "<input type=\"hidden\" name=\"AMPWIDTH\" value=$AMP_WIDTH>\n" .
    "<input type=\"hidden\" name=\"AMPTHRESHHOLD\" value=$AMP_THRESHHOLD>\n" .
    "<input type=\"hidden\" name=\"START_NUM\" value=>\n" .
    "<input type=\"hidden\" name=\"END_NUM\" value=>\n" .
    "<table border=\"0\" width=600 cellpadding=2>\n" .
    "<tr><td>&nbsp;\n" .
    "</td>\n" .
    "<td>&nbsp;\n" .
    "</td></tr>\n" .
    "<tr>" .
    "<td colspan=2 bgcolor=\"666699\" align=center><font color=\"FFFFFF\">\n" .
    "<B>Enter window data for re-window</B>\n" .
    "</font></td></tr><br>\n" .
        "<tr><td>&nbsp;\n" .
    "</td>\n" .
    "<td>&nbsp;\n" .
    "</td></tr>\n" .
    "<tr>\n" .
    "  <td align=left width=300>1. Enter window size.</td>\n" .
    "  <td align=left>\n" .
    "  <input type=text name=\"WINDOWSIZE\" value=\"$window_size\" size=30>\n" .
    "  </td>\n" .
    "</tr>\n" .
    "<tr>\n" .
    "  <td align=left width=300>2. Enter window start (nucleotide position).</td>\n" .
    "  <td align=left>\n" .
    "  <input type=text name=\"START_POS\" value=\"$start_pos_in\" size=30>\n" .
    "  </td>\n" .
    "</tr>\n" .
    "<tr>\n" .
    "  <td align=left width=300>3. Enter window end (nucleotide position).</td>\n" .
    "  <td align=left>\n" .
    "  <input type=text name=\"END_POS\" value=\"$end_pos_in\" size=30>\n" .
    "  </td>\n" .
    "</tr>\n" .
    "<tr>\n" .
    "<td>4. Submit query:</td>\n" .
    "<td> " .
    "<input type=submit value=\"Submit Query\">" .
    "</td>\n" .
    "</tr>\n" .
    "<tr><td>&nbsp;\n" .
    "</td>\n" .
    "<td>&nbsp;\n" .
    "</td></tr>\n" .
    "</table>\n" .
    "</blockquote>\n" .
    "</form>\n";
 
    ## "<tr>" .
    ## "<td colspan=2 bgcolor=\"666699\" align=center><font color=\"FFFFFF\">\n" .
    ## "<B>Detail DKView:</B>\n" .
    ## "</font></td></tr><br>\n" .
    ##     "<tr><td>&nbsp;\n" .
    ## "</td>\n" .
    ## "<td>&nbsp;\n" .
    ## "</td></tr>\n" .

  return ($lines_1, $lines_2);  
}

######################################################################
sub Make_upload_html {   

  my ($org, $mapped_cache_id, $filename, $total_mapped_tags, 
      $total_not_mapped_tags, $total_input_tags, $total_mapped_unique_tags, 
      $total_not_mapped_unique_tags,
      $total_input_unique_tags) = @_; 

  my @lines;
 
  push @lines, "<form name=\"dkdownloadform\" action=\"DKDownload\" method=post target=_blank>\n" .
    "<input type=\"hidden\" name=\"CACHE_ID\" value=$mapped_cache_id>\n" .
    "<input type=\"hidden\" name=\"FILENAME\" value=$filename>\n" .
    "<input type=\"hidden\" name=\"ORG\" value=$org>\n" .
    "<blockquote>" .
    "<table border=\"1\" width=80% cellpadding=2>\n" .
    "<tr bgcolor=\"#666699\">" .
    "<td width=20%><font color=\"white\"><b>&nbsp;</b></font></td>\n" .
    "<td width=20%><font color=\"white\"><b>Mapped</b></td>" .
    "<td NOWRAP width=20%><font color=\"white\"><b>Not Mapped</b></td>" .
    "<td NOWRAP width=20%><font color=\"white\"><b>Total</b></td>" .
    "</tr>\n" .
    "<tr>" .
    "<td width=20%>Total tags in input</td>\n" .
    "<td width=20%>$total_mapped_tags</td>" .
    "<td width=20%>$total_not_mapped_tags</td>" .
    "<td width=20%>$total_input_tags</td>" .
    "</tr>\n" .
    "<tr>" .
    "<td width=20%>Unique tags in input</td>\n" .
    "<td width=20%>$total_mapped_unique_tags</td>" .
    "<td width=20>$total_not_mapped_unique_tags</td>" .
    "<td width=20>$total_input_unique_tags</td>" .
    "</tr>\n" .
    ## "</tr>\n" .
    "</table>\n" .
    "<br><br>" .
    "<center><input type=submit value=\"Download mapped tags\"></center>" .
    ## "</blockquote>\n" .
    ## "<blockquote>" .
    "</form>\n" .
    "<form name=\"dkform\" action=\"DKView\") method=post target=_blank>\n" .
    "<input type=\"hidden\" name=\"CACHE_ID\" value=$mapped_cache_id>\n" .
    "<input type=\"hidden\" name=\"FILENAME\" value=$filename>\n" .
    "<input type=\"hidden\" name=\"ORG\" value=$org>\n" .
    "<table border=\"0\" width=90% cellpadding=2>\n" .
    "<tr><td>&nbsp;\n" .
    "</td>\n" .
    "<td>&nbsp;\n" .
    "</td></tr>\n" .
    "<tr>" .
    "<td colspan=2 bgcolor=\"666699\" align=center><font color=\"FFFFFF\">\n" .
    "<B>Enter window size for smoothing data</B>\n" .
    "</font></td></tr><br>\n" .
        "<tr><td>&nbsp;\n" .
    "</td>\n" .
    "<td>&nbsp;\n" .
    "</td></tr>\n" .
    "<tr>\n" .
    "  <td align=left width=45%>1. Enter window size.</td>\n" .
    "  <td align=left>\n" .
    "  <input type=text name=\"WINDOWSIZE\" value=\"200\" size=30>\n" .
    "  </td>\n" .
    "</tr>\n" .
    "  <input type=hidden name=\"AMPWIDTH\" value=\"1\" size=30>\n" .
    "<tr>\n" .
    "  <td align=left width=45%>2. Enter amplification fold change.</td>\n" .
    "  <td align=left>\n" .
    "  <input type=text name=\"AMPTHRESHHOLD\" value=\"7\" size=30>\n" .
    "  </td>\n" .
    "</tr>\n" .
    "  <input type=hidden name=\"DELWIDTH\" value=\"1\" size=30>\n" .
    "<tr>\n" .
    "  <td align=left width=45%>3. Enter deletion fold change.</td>\n" .
    "  <td align=left>\n" .
    "  <input type=text name=\"DELTHRESHHOLD\" value=\"0.1\" size=30>\n" .
    "  </td>\n" .
    "</tr>\n" .
    "<tr>\n" .
    "<td>4. Submit query:</td>\n" .
    "<td> " .
    "<input type=button onclick=\"dkform.submit()\" value=\"Submit Query\">" .
    "</td>\n" .
    "</tr>\n" .
    "<tr><td>&nbsp;\n" .
    "</td>\n" .
    "<td>&nbsp;\n" .
    "</td></tr>\n" .
    "</table>\n" .
    "</blockquote>\n" .
    "</form>\n";
  return (join "", @lines);
}

######################################################################
sub Make_lib_page_html {   
  my ($name, $organism, $keywords, $tags_plus, $mapped_tags_plus, $utags, 
      $mapped_utags, $tissue, $histology, $preparation, $mutations, 
      $patient_age, $patient_sex, $other_info, $tag_enzyme, $anchor_enzyme,
      $supplier, $producer, $laboratory, $references) =@_; 

 
  my (@rows);
  push @rows, DividerBar("Library ID");
  push @rows,
      "<BR>" .
      "<table width=95% cellpadding=1>";
  push @rows,
      "<tr><td valign=top width=30%><b>SAGE DK Library Name:</b></td>" .
      "<td>$name</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Organism:</b></td><td>$organism</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Library Keywords:</b></td>" .
      "<td>$keywords</td></tr>";
  push @rows,
      "</table><br>";
 
  push @rows, DividerBar("Tag Info");
  push @rows,
      "<BR>" .
      "<table width=95% cellpadding=1>";
  push @rows,
      "<tr><td valign=top width=30%><b>#Total tags:</b></td>" .
      "<td>$tags_plus</td></tr>";
  push @rows,
      "<tr><td valign=top width=30%><b>#Mapped Total tags:</b></td>" .
      "<td>$mapped_tags_plus</td></tr>";
 
  push @rows,
      "<tr><td valign=top><b>#Unique tags:</b></td>" .
      "<td>$utags</td></tr>";
  push @rows,
      "<tr><td valign=top><b>#Mapped Unique tags:</b></td>" .
      "<td>$mapped_utags</td></tr>";
  push @rows,
      "</table><br>";
 
  push @rows, DividerBar("Tissue Info");
  push @rows,
      "<BR>" .
      "<table width=95% cellpadding=1>";
  push @rows,
      "<tr><td valign=top width=30%><b>Tissue:</b></td>" .
      "<td>$tissue</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Cell/Histology type:</b></td>" .
      "<td>$histology</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Tissue preparation:</b></td>" .
      "<td>$preparation</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Mutations:</b></td>" .
      "<td>$mutations</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Patient age:</b></td>" .
      "<td>$patient_age</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Sex:</b></td>" .
      "<td>$patient_sex</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Other info:</b></td>" .
      "<td>$other_info</td></tr>";
  push @rows,
      "</table><br>";
 
  push @rows, DividerBar("Library Preparation Info");
  push @rows,
      "<BR>" .
      "<table width=95% cellpadding=1>";
  push @rows,
      "<tr><td valign=top width=30%><b>Tagging enzyme:</b></td>" .
      "<td>$tag_enzyme</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Anchoring enzyme:</b></td>" .
      "<td>$anchor_enzyme</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Tissue or cell line supplier:</b></td>" .
      "<td>$supplier</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Library preparer:</b></td>" .
      "<td>$producer</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Prepared in lab of:</b></td>" .
      "<td>$laboratory</td></tr>";
  push @rows,
      "<tr><td valign=top><b>References:</b></td>" .
      "<td>$references</td></tr>";
  push @rows,
      "</table><br>";
 
  return join("\n", @rows);

}  
######################################################################
sub smooth_data {   
  
  my ($pos) = @_;
  return int(($pos + 500)/1000);
}

######################################################################
sub numerically { $a <=> $b; }
 
######################################################################
1;
