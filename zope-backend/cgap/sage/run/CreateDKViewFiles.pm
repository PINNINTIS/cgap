#####################################################################
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

my $BASE;

my $dk_cache = new Cache(CACHE_ROOT, DK_CACHE_PREFIX);
my $CACHE_FAIL = 0;

######################################################################

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
  my %mapped_tags;
  my %not_mapped_tags;
  my @mapped_lines;
  my @input_tags;
  my %unique_input_tags;
  my $total_input_tags;
  my $total_input_unique_tags;
  my $total_mapped_tags;
  my $total_mapped_unique_tags;
  my $map_f = "/share/content/CGAP/SAGE/data/dkmap.dat";
 
  if( $filename eq "" ) {
    return "Please enter the file name.";
  }

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
  open(INF, $map_f) or die "cannot open $map_f";
  while (<INF>) {
    s/[\r\n]+//;
    s/^\s+//;
    if( $_ eq "" ) {
      next;
    }
    my ($tag, $chr, $pos, $strand, $tag_num) = split /\t/;
    my $freq;
    if (defined $exp{$tag}) {
      $freq = $exp{$tag};
      $total_mapped_tags = $total_mapped_tags + $freq; 
      $total_mapped_unique_tags++;
    } else {
      $freq = 0;
    }
    ## print OUT "$_\t$freq\n";
    push @mapped_lines, "$_\t$freq\n";
  }
  close INF;
 
  my $total_not_mapped_tags = $total_input_tags - $total_mapped_tags;
  my $total_not_mapped_unique_tags = 
          $total_input_unique_tags - $total_mapped_unique_tags;

  my $mapped_cache_id;
  my $data = join "", @mapped_lines;
  my $mapped_cache_id = WriteDKDataToCache($data);
  if( $mapped_cache_id == 0 ) {
    print "There is a error in the DKView process.";
    return "";
  }

  my @lines; 
  
  push @lines, "<form name=\"dkdownloadform\" action=\"DKDownload\" method=post target=_blank>\n" .
    "<input type=\"hidden\" name=\"CACHE_ID\" value=$mapped_cache_id>\n" .
    "<input type=\"hidden\" name=\"FILENAME\" value=$filename>\n" .
    "<input type=\"hidden\" name=\"ORG\" value=$org>\n" .
    "<blockquote>" .
    "<table border=\"1\" width=80% cellpadding=2>\n" .
    "<tr bgcolor=\"#38639d\">" .
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
    "<input type=submit value=\"Download mapped tags\">" .
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
    "<td colspan=2 bgcolor=\"336699\" align=center><font color=\"FFFFFF\">\n" .
    "<B>Enter window size for smooting data</B>\n" .
    "</font></td></tr><br>\n" .
        "<tr><td>&nbsp;\n" .
    "</td>\n" .
    "<td>&nbsp;\n" .
    "</td></tr>\n" .
    "<tr>\n" .
    "  <td align=left width=45%>1. Enter the window size.</td>\n" .
    "  <td align=left>\n" .
    "  <input type=text name=\"WINDOWSIZE\" value=\"200\" size=30>\n" .
    "  </td>\n" .
    "</tr>\n" . 
    "<tr>\n" .
    "<td>2. Submit query:</td>\n" .
    "<td> " .
    "<input type=button onclick=\"dkform.submit()\" value=\"Submit Query\">" .
    "</td>\n" .
    " </tr>\n" .
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
sub DKDownload_1 {
  my ($base, $mapped_cache_id) = @_;

  my $cache_filename = $dk_cache->FindCacheFile($mapped_cache_id);
  open(IN, "$cache_filename") or die "Can't open $cache_filename.";
 
  my @output;
  push @output, "Tag\tChr\tPosition\tStrand\tFreq\n";
  while (<IN>) {
    chop;
    my ($tag, $chr, $pos, $strand, $tag_num, $freq) = split /\t/, $_;
    if( $freq != 0 ) {
      push @output, join ("\t", $tag, $chr, $pos, $strand, $freq) . "\n";
    }
  }
  close (IN);

  return "", @output;
}
######################################################################
sub DKView_1 {
  my ($base, $org, $mapped_cache_id, $window_size, $filename) = @_;
 
  my %exp;
  my %freq;
  my @mapped_lines;
  my $data;

  my $bin_size = BIN_SIZE;
 
  my ($tag, $chr, $pos, $strand, $tag_num, $freq);
  my (%mapped_data, $n_virtual_tags, $sum_freq);
  my (%freq);
  my $flag;
  my (@window_info, @high_window_info, @low_window_info);
  my $high_window_size = $window_size + 400;
  my $low_window_size;
  if( $window_size >= 500 ) {
    $low_window_size = $window_size - 400;
  } 
  else {
    $low_window_size = int($window_size/2) ;
  }
  my @chr_order = ("1", "2", "3", "4", "5", "6", "7", "8", "9",
      "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
      "20", "21", "22", "X", "Y");
  my $data;
   
  if ($window_size % 2 != 0) {
    $window_size++;
    print STDERR "increasing window size by 1 to $window_size\n";
  }
  if ($high_window_size % 2 != 0) {
    $high_window_size++;
  }
  if ($low_window_size % 2 != 0) {
    $low_window_size++;
  }
  my $half_window = $window_size / 2;
  my $high_half_window = $high_window_size / 2;
  my $low_half_window = $low_window_size / 2;
   
  my $cache_filename = $dk_cache->FindCacheFile($mapped_cache_id);
  open(IN, "$cache_filename") or die "Can't open $cache_filename.";

  while (<IN>) {
    chop;
    ($tag, $chr, $pos, $strand, $tag_num, $freq) = split /\t/, $_;
    push @{ $mapped_data{$chr} }, $_;
    push @{ $freq{$chr} }, $freq;
    $sum_freq += $freq;
    $n_virtual_tags++;
  }

  close (IN);

  #my $overall_avg = sprintf("%.3f", $sum_freq/$n_virtual_tags + 0.0005);
  my $overall_avg = $sum_freq/$n_virtual_tags;
  my %n_virtual_tags_per_chr;
  for my $chr (@chr_order) {
    $n_virtual_tags_per_chr{$chr} = @{ $freq{$chr} };
  }
   
  for my $chr (@chr_order) {
    for my $f (@{ $freq{$chr} }) {
      $f = $f / $overall_avg;
    }
  }
   
  ## $flag = 1 for low, 2 for normal, 3 for high

  ## print "average_freq for $sum_freq tags over $n_virtual_tags = " .
  ##   sprintf("%.2f", $overall_avg) . "\n";
  for $chr (@chr_order) {
    for (my $tag_num = 0; $tag_num < @{ $freq{$chr} }; $tag_num++) {
      $flag = 2;
      $window_value{$chr}[$tag_num] = ComputeWindow($chr, $tag_num, 
        $half_window, \%n_virtual_tags_per_chr, $window_size, \%freq, $flag);
      $flag = 3;
      $high_window_value{$chr}[$tag_num] = ComputeWindow($chr, $tag_num, 
        $high_half_window, \%n_virtual_tags_per_chr, $high_window_size, 
        \%freq, $flag);
      $flag = 1;
      $low_window_value{$chr}[$tag_num] = ComputeWindow($chr, $tag_num, 
        $low_half_window, \%n_virtual_tags_per_chr, $low_window_size, 
        \%freq, $flag);
    }
  }
  for my $chr (@chr_order) {
    for (my $i = 0; $i < @{ $window_value{$chr} }; $i++) {
      my $value = sprintf("%.2f", $window_value{$chr}[$i]);
      my $f = sprintf("%.2f", $freq{$chr}[$i]);
      my $mapped_value = $mapped_data{$chr}[$i];
      my $high_value = sprintf("%.2f", $high_window_value{$chr}[$i]);
      my $low_value = sprintf("%.2f", $low_window_value{$chr}[$i]);
      push @window_info, "$mapped_value\t$f\t$value\t$high_value\t$low_value\n";
    }
  }

  $data = join "", @window_info;
  my $window_info_cache_id = WriteDKDataToCache($data);
  if( $window_info_cache_id == 0 ) {
    return "There is a error in the DKView process.";
  }

  undef %mapped_data;
  undef $data;
  undef %freq;
  undef @window_info;
  undef @high_window_info;
  undef @low_window_info;
  return pick_nth_tag($window_info_cache_id, $bin_size, $window_size, 
                      $org, $filename);
}

 
######################################################################
sub ComputeWindow {
  my ($chr, $tag_num, $half_window, $n_virtual_tags_per_chr_ref,
      $window_size, $freq_ref, $flag) = @_;
 
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
      if( $flag == 1 ) {
        return (
            $low_window_value{$chr}[$tag_num - 1] * ($window_size + 1) -
            $freq{$chr}[$tag_num - $half_window - 1] +
            $freq{$chr}[$tag_num + $half_window]
          ) / ($window_size + 1);
      }
      elsif( $flag == 2 ) {
        return (
            $window_value{$chr}[$tag_num - 1] * ($window_size + 1) -
            $freq{$chr}[$tag_num - $half_window - 1] +
            $freq{$chr}[$tag_num + $half_window]
          ) / ($window_size + 1);
      }
      elsif( $flag == 3 ) {
        return (
            $high_window_value{$chr}[$tag_num - 1] * ($window_size + 1) -
            $freq{$chr}[$tag_num - $half_window - 1] +
            $freq{$chr}[$tag_num + $half_window]
          ) / ($window_size + 1);
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
sub pick_nth_tag {
# input is a sequence of window-averaged values for DK tags for a single
# chromosome; detailed format:
#    tag
#    chromosome
#    base pair
#    strand
#    tag number
#    absolute frequency
#    normalized frequence
#    window-averaged value
# output is a binning; detailed format:
#    bin number
#    chromosome
#    start base pair position
#    end base pair position
#    start tag number
#    end tag number
#    average of window-averaged values
 
  my ($window_info_cache_id, $bin_size, $window_size, $org, $filename) = @_;
 
  ## my @window_dk_data = @{$window_dk_data_ref};
  my $n;
  my ($tag, $chr, $pos, $strand, $tag_num, $freq, $normal_freq, $window_val);
  my ($last_chr);
  my (@lines, %chr_2_image_id);
  my (@image_map);
  my @chr_order = ("1", "2", "3", "4", "5", "6", "7", "8", "9",
      "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
      "20", "21", "22", "X", "Y");
  my (%max);
  for(my $i=0; $i<@chr_order; $i++) {
    $max{$chr_order[$i]} = 0;
  }

  my ($binned_data_id, $binned_data_filename) = $dk_cache->MakeCacheFile();
  if ($binned_data_id != $CACHE_FAIL) {
    open(SOUT, ">$binned_data_filename") or 
              die "Can not open $binned_data_filename \n";
  }
  else {
    print "Cache failed \n";
    return "";
  }

  my $cache_filename = $dk_cache->FindCacheFile($window_info_cache_id);
  open(IN, "$cache_filename") or die "Can't open $cache_filename.";
  while (<IN>) {
    chop;
    ($tag, $chr, $pos, $strand, $tag_num, $freq, $normal_freq, $window_val) =
        split /\t/, $_;
    if ($last_chr && $last_chr ne $chr) {
      DoBin($last_chr, $n, $bin_size, \%max);
      $n = 0;
    }
    $last_chr = $chr;
    $n++;
    push @window_val, $window_val;
    push @start, $pos;
    if ($n % $bin_size == 0) {
      DoBin($chr, $n, $bin_size, \%max);
    }
  }
 
  close (IN);

  if ($n % $bin_size > 0) {
    DoBin($chr, $n, $bin_size, \%max);
  }
 
  close SOUT;
  chmod 0666, $binned_data_filename;

  for my $chr (@chr_order) {
    my $chrmapname = "chrmap" . $chr;
    push @image_map, "<map name=\"$chrmapname\">";
    $chr_2_image_id{$chr} =  
      Graph($chr, \@image_map, $window_info_cache_id, $window_size, 
            $filename, $binned_data_id, $max{$chr});
    push @image_map, "</map>";
  }
 
  ## push @lines, "<br><center>Filename: $filename; Window size: $window_size </center><br><br>";

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
  print SOUT join("\t",
      $chr,
      $bn,
      $chr,
      $s_pos,
      $e_pos,
      $n - scalar(@window_val) + 1,
      $n,
      $avg
  ) . "\n";

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
  my($chr, $image_map_ref, $window_info_cache_id, $window_size, 
     $filename, $binned_data_id, $max) = @_;
 
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
  for (my $i = 1; $i < @{ $binned_data{$chr} } - 1; $i++ ) {
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
    if ($x0 == $x1) {
      $im->line (
          $x0+30,
          $y0,
          $x1+30,
          $y1,
          $COLORS{red}
      );
    } else {
      $im->filledRectangle (
          $x0+30,
          $y0,
          $x1+30,
          $y1,
          $COLORS{red}
      );
    }
    $last_val = $value;
    my $x0_pos = $x0+30;
    my $x1_pos = $x1+30;
    push @{ $image_map_ref },
      "<area shape=rect coords=\"$x0_pos,$y0,$x1_pos,$y1\" " .
      "href=javascript:spawn(\"DKViewDetail?CHR=$chr&POS=$i&CACHE_ID=$window_info_cache_id&WINDOWSIZE=$window_size&FILENAME=$filename&BINNED_DATA_CACHE_ID=$binned_data_id\")>";
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
 
# input is a sequence of window-averaged values for DK tags for a single
# chromosome; detailed format:
#    tag
#    chromosome
#    base pair
#    strand
#    tag number
#    absolute frequency
#    normalized frequence
#    window-averaged value
# output is a binning; detailed format:
#    bin number
#    chromosome
#    start base pair position
#    end base pair position
#    start tag number
#    end tag number
#    average of window-averaged values
 
  my ($base, $chr_in, $pos_in, $window_info_cache_id, $window_size, 
      $filename, $binned_data_id) = @_;
 
  my $bin_size = BIN_SIZE;
  my $CHOOSE_WAY = 2;
 
  my ($n);
  my ($tag, $chr, $pos, $strand, $tag_num, $freq, $normal_freq, $window_val);
  my ($last_chr);
  my (@lines, $chr_2_image_id, $high_chr_2_image_id, $low_chr_2_image_id);
  my (@image_map);
  my ($start_pos, $end_pos);
  my @chr_order = ("1", "2", "3", "4", "5", "6", "7", "8", "9",
      "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
      "20", "21", "22", "X", "Y");
  my (%max);
  my ($detail_max);
  for(my $i=0; $i<@chr_order; $i++) {
    $max{$chr_order[$i]} = 0;
  }
  $detail_max = 0;

  my $org = "Human";
  ## my $UCSC_DB = "hg18";
  my $UCSC_DB = "";

  my $high_window_size = $window_size + 400;
  my $low_window_size;
  if( $window_size >= 500 ) {
    $low_window_size = $window_size - 400;
  }
  else {
    $low_window_size = int($window_size/2) ;
  }

  undef @start;
  undef @end;
  undef @window_val;

  ## $flag = 1 for low, 2 for normal, 3 for high

  Do_window_info_data ($chr_in, $window_info_cache_id, $bin_size, $CHOOSE_WAY);

  if ($dk_cache->FindCacheFile($binned_data_id) eq $CACHE_FAIL) {
    return "Cache expired";
  }
  my $binned_data_filename = $dk_cache->FindCacheFile($binned_data_id);
  open(IN,"$binned_data_filename") or die "Can't open $binned_data_filename.\n";
  while (<IN>) {
    chop;
    my ( $chr,
         $bn,
         $chr,
         $s_pos,
         $e_pos,
         $n_value,
         $n,
         $avg ) = split "\t", $_;
    push @{ $binned_data{$chr} }, join("\t",
        $bn,
        $chr,
        $s_pos,
        $e_pos,
        $n_value,
        $n,
        $avg
      );
    if( $avg > $max{$chr} ) {
      $max{$chr} = $avg;
    }
  }
  close (IN);

  my $current_pos = ($pos_in-1)*100/$CHOOSE_WAY;
  for (my $i = 1; $i < @{ $binned_data_detail{$chr_in} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or 
        $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }
 
    if( not defined  $binned_data_detail{$chr_in}[$i] ) {
      next;
    }
 
    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data_detail{$chr_in}[$i]);
    if( $value > $detail_max ) {
      $detail_max = $value;
    }
  }
 
  if( $detail_max >= 4 ) {
    ($chr_2_image_id, $start_pos, $end_pos) = 
          Graph_detail_high($chr_in, $pos_in, $CHOOSE_WAY, $detail_max);
    ($high_chr_2_image_id) = 
          Graph_high_detail_high($chr_in, $pos_in, $CHOOSE_WAY, $detail_max);
    ($low_chr_2_image_id) = 
          Graph_low_detail_high($chr_in, $pos_in, $CHOOSE_WAY, $detail_max);
  }
  elsif( $detail_max < 0.5 ) {
    ($chr_2_image_id, $start_pos, $end_pos) = 
          Graph_detail_low($chr_in, $pos_in, $CHOOSE_WAY, $detail_max);
    ($high_chr_2_image_id) = 
          Graph_high_detail_low($chr_in, $pos_in, $CHOOSE_WAY, $detail_max);
    ($low_chr_2_image_id) = 
          Graph_low_detail_low($chr_in, $pos_in, $CHOOSE_WAY, $detail_max);
  }
  else {
    ($chr_2_image_id, $start_pos, $end_pos) = 
          Graph_detail($chr_in, $pos_in, $CHOOSE_WAY);
    ($high_chr_2_image_id) = 
          Graph_high_detail($chr_in, $pos_in, $CHOOSE_WAY);
    ($low_chr_2_image_id) = 
          Graph_low_detail($chr_in, $pos_in, $CHOOSE_WAY);
  }
 
  my $sign = "UCSC browser.";
  my $chr_for_url = "chr" . $chr_in;
  my $highperlink = "<p><a href=javascript:spawn(\"" .
          "http://genome.ucsc.edu/cgi-bin/hgTracks?clade=vertebrate" .
          "&org=$org&db=$UCSC_DB&position=$chr_for_url:$start_pos-$end_pos" .
          "&pix=620\")>$sign</a><br><br>";

          ## "&pix=620&hgsid=42606403\")>$sign</a><br><br>";

  my $window_size_for_html = "Window size: $window_size <br><br>";
  push @lines, $window_size_for_html;
  push @lines, $highperlink;
  push @lines, "<img src=\"DKImage?CACHE=$chr_2_image_id&CHR=$chr_in\" border=0><br>";
  my $window_size_for_html = "Window size: $high_window_size <br><br>";
  push @lines, $window_size_for_html;
  push @lines, "<img src=\"DKImage?CACHE=$high_chr_2_image_id&CHR=$chr_in\" border=0><br>";
  my $window_size_for_html = "Window size: $low_window_size <br><br>";
  push @lines, $window_size_for_html;
  push @lines, "<img src=\"DKImage?CACHE=$low_chr_2_image_id&CHR=$chr_in\" border=0><br>";
 
  my $chrmapname = "chrmap" . $chr_in;
  push @image_map, "<map name=\"$chrmapname\">";
  my $id;
  $id = Graph_chr($chr_in, \@image_map, $window_info_cache_id, $pos_in, 
                  $window_size, $filename, $binned_data_id);
  push @image_map, "</map>";
 
  push @lines, "<img src=\"DKImage?CACHE=$id&CHR=$chr_in\" border=0 usemap=\"#$chrmapname\"><br>";
  push @lines, @image_map;

  return (join "", @lines);
}
 
######################################################################
sub Do_window_info_data {
  my ($chr_in, $window_info_cache_id, $bin_size, $CHOOSE_WAY) = @_;
  my ($n, $flag);

  undef @start;
  undef @end;
  undef @window_val;
 
  ## $flag = 1 for low, 2 for normal, 3 for high
 
  my $cache_filename = $dk_cache->FindCacheFile($window_info_cache_id);
  open(IN, "$cache_filename") or die "Can't open $cache_filename.";
  while (<IN>) {
    chop;
    my ($tag, $chr, $pos, $strand, $tag_num, $freq, $normal_freq, 
        $window_val, $high_window_val, $low_window_val) = split /\t/, $_;
    if( $chr ne $chr_in ) {
      next;
    }
    $n++;
    push @window_val, $window_val;
    push @high_window_val, $high_window_val;
    push @low_window_val, $low_window_val;
    push @start, $pos;
    if ($n % $CHOOSE_WAY == 0) {
      DoBin_detail($chr_in, $n, $bin_size);
    }
  }
  close (IN);
 
  if ($n % $bin_size > 0) {
    DoBin_detail($chr_in, $n, $bin_size);
  }
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
  ## low:
  my $mid = int(@low_window_val / 2);
  my $avg = $low_window_val[$mid];
  push @{ $binned_data_low_detail{$chr} }, join("\t",
            $bn,
            $chr,
            $s_pos,
            $e_pos,
            $n - scalar(@low_window_val) + 1,
            $n,
            $avg
          );
  ## normal:
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
  ## high:
  my $mid = int(@high_window_val / 2);
  my $avg = $high_window_val[$mid];
  push @{ $binned_data_high_detail{$chr} }, join("\t",
            $bn,
            $chr,
            $s_pos,
            $e_pos,
            $n - scalar(@high_window_val) + 1,
            $n,
            $avg
          );

  undef @start;
  undef @end;
  undef @window_val;
  undef @high_window_val;
  undef @low_window_val;
}
 
######################################################################
sub Graph_detail {
  my ($chr, $pos, $CHOOSE_WAY) = @_;

use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  ## my $GRAPH_HEIGHT        = 200 * 100/$CHOOSE_WAY;
  my $GRAPH_HEIGHT        = 50 + 400;
  ## my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * @{ $binned_data_detail{$chr} };
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * 800; 
  ## my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 30;
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 100;
  ## my $IMAGE_WIDTH         = $GRAPH_WIDTH  + 30;
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
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT, 0, $COLORS{black});
  for (my $y0 = $GRAPH_HEIGHT - 50; $y0 >= 0; $y0 = $y0 - int(400/3)) {
    my $x0 = 0;
    $im->string(gdSmallFont, $x0, $y0, int( 1 + ($GRAPH_HEIGHT - $y0)/int(400/3)), $COLORS{black});
  }
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*100/$CHOOSE_WAY;
  ## my $current_pos = $pos*100/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  for (my $i = 1; $i < @{ $binned_data_detail{$chr} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }

    if( not defined  $binned_data_detail{$chr}[$i] ) {
      next;
    }

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data_detail{$chr}[$i]);

    if( ($current_pos - 800/$CHOOSE_WAY <= 0) and ($i == 1) ) {
    
      $left_flag = 1;
    }
    elsif ( $i == $current_pos - 800/$CHOOSE_WAY ) {
      $pos_start = $start_pos;
    }

    my $len = @{ $binned_data_detail{$chr} } - 1;
    if( ($current_pos + 800/$CHOOSE_WAY >= $len) and ($i == $len - 1) ) {
      $pos_end = $start_pos;
      $right_flag = 1;
    } 
    elsif( $i == $current_pos + 800/$CHOOSE_WAY ) {
      $pos_end = $start_pos;
    }

    if( $current_pos == $i ) {
      $pos_click = $start_pos;
    }

    my $tmp_i = $i - ($current_pos - 800/$CHOOSE_WAY);

    my $x0 = $PIX_PER_INTERVAL * ($tmp_i - 1);
    my $x1 = $PIX_PER_INTERVAL * $tmp_i;
    my $y0;
    if( $value <= 1 ) {
      $y0 = $GRAPH_HEIGHT - int(50 * $value);
    }
    else {
      $y0 = $GRAPH_HEIGHT - int(50 + ($value-1) * (400/3));
    }
    my $y1;
    ## print "8888: $i, $value<br>";
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( $x0 == 426 ) {
      $mid_value = $y0;
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

  my $x0 = 401 + 30 + 25;
  my $x1 = $x0;
  ## my $y0 = $GRAPH_HEIGHT - $mid_value;
  my $y0 = $mid_value;
  my $y1 = $GRAPH_HEIGHT;
  $im->line($x0, $y0, $x1, $y1, $COLORS{lightblue});

  my $x0 = 0 + 30;
  my $x1 = $GRAPH_WIDTH + 30;
  my $y0 = $GRAPH_HEIGHT - int(50 * 1);
  my $y1 = $y0;
  $im->line($x0, $y0, $x1, $y1, $COLORS{white});


  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;
  if( $left_flag == 1 ) {
    my $x0 = 800/$CHOOSE_WAY - $current_pos;
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  elsif( $right_flag == 1 ) {
    my $x0 = 800 - (($current_pos + 800/$CHOOSE_WAY) -  (@{ $binned_data_detail{$chr} } - 2));
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
  }
  else {
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return ($cache_id, $pos_start, $pos_end);
}

######################################################################
sub Graph_detail_high {
  my ($chr, $pos, $CHOOSE_WAY, $max) = @_;

use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  ## my $GRAPH_HEIGHT        = 50 + 100 * ( int($detail_max) + 2 );
  my $GRAPH_HEIGHT        = 200;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * 800; 
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 100;
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
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  my $x0 = 0;
  my $y0 = $GRAPH_HEIGHT;
  $im->string(gdSmallFont, $x0, $y0, 0, $COLORS{red});
  $y0 = $GRAPH_HEIGHT - int(50 * ($max/($max + 1)) * 4);
  $im->string(gdSmallFont, $x0, $y0, $max, $COLORS{red});
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*100/$CHOOSE_WAY;
  ## my $current_pos = $pos*100/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  for (my $i = 1; $i < @{ $binned_data_detail{$chr} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }

    if( not defined  $binned_data_detail{$chr}[$i] ) {
      next;
    }

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data_detail{$chr}[$i]);

    if( ($current_pos - 800/$CHOOSE_WAY <= 0) and ($i == 1) ) {
    
      $left_flag = 1;
    }
    elsif ( $i == $current_pos - 800/$CHOOSE_WAY ) {
      $pos_start = $start_pos;
    }

    my $len = @{ $binned_data_detail{$chr} } - 1;
    if( ($current_pos + 800/$CHOOSE_WAY >= $len) and ($i == $len - 1) ) {
      $pos_end = $start_pos;
      $right_flag = 1;
    } 
    elsif( $i == $current_pos + 800/$CHOOSE_WAY ) {
      $pos_end = $start_pos;
    }

    if( $current_pos == $i ) {
      $pos_click = $start_pos;
    }

    my $tmp_i = $i - ($current_pos - 800/$CHOOSE_WAY);

    my $x0 = $PIX_PER_INTERVAL * ($tmp_i - 1);
    my $x1 = $PIX_PER_INTERVAL * $tmp_i;
    my $y0;
    $y0 = $GRAPH_HEIGHT - int(50 * ($last_val/($max + 1)) * 4);
    my $y1;
    ## print "8888: $i, $value<br>";
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( $x0 == 426 ) {
      $mid_value = $y0;
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

  my $x0 = 401 + 30 + 25;
  my $x1 = $x0;
  ## my $y0 = $GRAPH_HEIGHT - $mid_value;
  my $y0 = $mid_value;
  my $y1 = $GRAPH_HEIGHT;
  $im->line($x0, $y0, $x1, $y1, $COLORS{lightblue});

  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;
  if( $left_flag == 1 ) {
    my $x0 = 800/$CHOOSE_WAY - $current_pos;
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  elsif( $right_flag == 1 ) {
    my $x0 = 800 - (($current_pos + 800/$CHOOSE_WAY) -  (@{ $binned_data_detail{$chr} } - 2));
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
  }
  else {
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return ($cache_id, $pos_start, $pos_end);
}


######################################################################
sub Graph_chr {
  my ($chr, $image_map_ref, $window_info_cache_id, $pos_in, 
      $window_size, $filename, $binned_data_id) = @_;
 
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
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );
  for (my $y0 = $GRAPH_HEIGHT; $y0 >= 0; $y0 = $y0 - 50) {
    my $x0 = 0;
    $im->string(gdSmallFont, $x0, $y0, int(($GRAPH_HEIGHT - $y0)/50), $COLORS{black});
  }
 
  my $last_val;
  for (my $i = 1; $i < @{ $binned_data{$chr} } - 1; $i++ ) {
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
    if( abs($i - $pos_in) <= 8 ) {
      if( ($i - $pos_in) == 0 ) {
        $color = $COLORS{lightblue};
      }
      else {
        $color = $COLORS{lightgray};
      }
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
      "href=javascript:spawn(\"DKViewDetail?CHR=$chr&POS=$i&CACHE_ID=$window_info_cache_id&WINDOWSIZE=$window_size&FILENAME=$filename&BINNED_DATA_CACHE_ID=$binned_data_id\")>";
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
sub Graph_chr_high {
  my ($chr, $image_map_ref, $window_info_cache_id, $pos_in, 
      $window_size, $filename, $binned_data_id, $max) = @_;
 
use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  my $GRAPH_HEIGHT        = 50 * ( int($max) + 2 );
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
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );
  for (my $y0 = $GRAPH_HEIGHT; $y0 >= 0; $y0 = $y0 - 50) {
    my $x0 = 0;
    $im->string(gdSmallFont, $x0, $y0, int(($GRAPH_HEIGHT - $y0)/50), $COLORS{black});
  }
 
  my $last_val;
  for (my $i = 1; $i < @{ $binned_data{$chr} } - 1; $i++ ) {
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
    if( abs($i - $pos_in) <= 8 ) {
      if( ($i - $pos_in) == 0 ) {
        $color = $COLORS{lightblue};
      }
      else {
        $color = $COLORS{lightgray};
      }
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
      "href=javascript:spawn(\"DKViewDetail?CHR=$chr&POS=$i&CACHE_ID=$window_info_cache_id&WINDOWSIZE=$window_size&FILENAME=$filename&BINNED_DATA_CACHE_ID=$binned_data_id\")>";
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
  my ($chr, $pos, $CHOOSE_WAY, $max) = @_;

use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  my $GRAPH_HEIGHT        = 400 + 50;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * 800; 
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 100;
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
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT, 0, $COLORS{black});
  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT - 400, 1, $COLORS{black});
  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT - 450, 2, $COLORS{black});
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*100/$CHOOSE_WAY;
  ## my $current_pos = $pos*100/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  for (my $i = 1; $i < @{ $binned_data_detail{$chr} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }

    if( not defined  $binned_data_detail{$chr}[$i] ) {
      next;
    }

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data_detail{$chr}[$i]);

    if( ($current_pos - 800/$CHOOSE_WAY <= 0) and ($i == 1) ) {
    
      $left_flag = 1;
    }
    elsif ( $i == $current_pos - 800/$CHOOSE_WAY ) {
      $pos_start = $start_pos;
    }

    my $len = @{ $binned_data_detail{$chr} } - 1;
    if( ($current_pos + 800/$CHOOSE_WAY >= $len) and ($i == $len - 1) ) {
      $pos_end = $start_pos;
      $right_flag = 1;
    } 
    elsif( $i == $current_pos + 800/$CHOOSE_WAY ) {
      $pos_end = $start_pos;
    }

    if( $current_pos == $i ) {
      $pos_click = $start_pos;
    }

    my $tmp_i = $i - ($current_pos - 800/$CHOOSE_WAY);

    my $x0 = $PIX_PER_INTERVAL * ($tmp_i - 1);
    my $x1 = $PIX_PER_INTERVAL * $tmp_i;
    my $y0;
    $y0 = $GRAPH_HEIGHT - int(400 * $value);
    my $y1;
    ## print "8888: $i, $value<br>";
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( $x0 == 426 ) {
      $mid_value = $y0;
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

  my $x0 = 401 + 30 + 25;
  my $x1 = $x0;
  ## my $y0 = $GRAPH_HEIGHT - $mid_value;
  my $y0 = $mid_value;
  my $y1 = $GRAPH_HEIGHT;
  $im->line($x0, $y0, $x1, $y1, $COLORS{lightblue});

  my $x0 = 0 + 30;
  my $x1 = $GRAPH_WIDTH + 30;
  my $y0 = $GRAPH_HEIGHT - 400;
  my $y1 = $y0;
  $im->line($x0, $y0, $x1, $y1, $COLORS{white});


  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;
  if( $left_flag == 1 ) {
    my $x0 = 800/$CHOOSE_WAY - $current_pos;
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  elsif( $right_flag == 1 ) {
    my $x0 = 800 - (($current_pos + 800/$CHOOSE_WAY) -  (@{ $binned_data_detail{$chr} } - 2));
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
  }
  else {
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return ($cache_id, $pos_start, $pos_end);
}


######################################################################
sub Graph_chr_low {
  my ($chr, $image_map_ref, $window_info_cache_id, $pos_in, 
      $window_size, $filename, $binned_data_id, $max) = @_;
 
use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  my $GRAPH_HEIGHT        = 400 * (int($max) + 2);
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
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );
  for (my $y0 = $GRAPH_HEIGHT; $y0 >= 0; $y0 = $y0 - 400) {
    my $x0 = 0;
    $im->string(gdSmallFont, $x0, $y0, int(($GRAPH_HEIGHT - $y0)/400), $COLORS{black});
  }
 
  my $last_val;
  for (my $i = 1; $i < @{ $binned_data{$chr} } - 1; $i++ ) {
    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data{$chr}[$i]);
    my $x0 = $PIX_PER_INTERVAL * ($i - 1);
    my $x1 = $PIX_PER_INTERVAL * $i;
    my $y0 = $GRAPH_HEIGHT - int(400 * $last_val);
    my $y1;
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(400 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( abs($i - $pos_in) <= 8 ) {
      if( ($i - $pos_in) == 0 ) {
        $color = $COLORS{lightblue};
      }
      else {
        $color = $COLORS{lightgray};
      }
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
      "href=javascript:spawn(\"DKViewDetail?CHR=$chr&POS=$i&CACHE_ID=$window_info_cache_id&WINDOWSIZE=$window_size&FILENAME=$filename&BINNED_DATA_CACHE_ID=$binned_data_id\")>";
  }
  my $x0 = 0 + 30;
  my $x1 = $GRAPH_WIDTH + 30;
  my $y0 = $GRAPH_HEIGHT - int(400 * 1);
  my $y1 = $y0;
  $im->line($x0, $y0, $x1, $y1, $COLORS{white});
  $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+10, "Chromosome " . $chr,
    $COLORS{black});
 
  ## print "8888: call WriteDKGEToCache <br>";
  return WriteDKToCache($im->png, $chr)
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
 
  if ($dk_cache->FindCacheFile($cache_id) eq $CACHE_FAIL) {
    return "Cache expired";
  }
  my $filename = $dk_cache->FindCacheFile($cache_id);
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
sub Graph_high_detail {
  my ($chr, $pos, $CHOOSE_WAY) = @_;

use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  ## my $GRAPH_HEIGHT        = 200 * 100/$CHOOSE_WAY;
  my $GRAPH_HEIGHT        = 50 + 400;
  ## my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * @{ $binned_data_high_detail{$chr} };
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * 800; 
  ## my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 30;
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 100;
  ## my $IMAGE_WIDTH         = $GRAPH_WIDTH  + 30;
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
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT, 0, $COLORS{black});
  for (my $y0 = $GRAPH_HEIGHT - 50; $y0 >= 0; $y0 = $y0 - int(400/3)) {
    my $x0 = 0;
    $im->string(gdSmallFont, $x0, $y0, int( 1 + ($GRAPH_HEIGHT - $y0)/int(400/3)), $COLORS{black});
  }
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*100/$CHOOSE_WAY;
  ## my $current_pos = $pos*100/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  for (my $i = 1; $i < @{ $binned_data_high_detail{$chr} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }

    if( not defined  $binned_data_high_detail{$chr}[$i] ) {
      next;
    }

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data_high_detail{$chr}[$i]);

    if( ($current_pos - 800/$CHOOSE_WAY <= 0) and ($i == 1) ) {
    
      $left_flag = 1;
    }
    elsif ( $i == $current_pos - 800/$CHOOSE_WAY ) {
      $pos_start = $start_pos;
    }

    my $len = @{ $binned_data_high_detail{$chr} } - 1;
    if( ($current_pos + 800/$CHOOSE_WAY >= $len) and ($i == $len - 1) ) {
      $pos_end = $start_pos;
      $right_flag = 1;
    } 
    elsif( $i == $current_pos + 800/$CHOOSE_WAY ) {
      $pos_end = $start_pos;
    }

    if( $current_pos == $i ) {
      $pos_click = $start_pos;
    }

    my $tmp_i = $i - ($current_pos - 800/$CHOOSE_WAY);

    my $x0 = $PIX_PER_INTERVAL * ($tmp_i - 1);
    my $x1 = $PIX_PER_INTERVAL * $tmp_i;
    my $y0;
    if( $value <= 1 ) {
      $y0 = $GRAPH_HEIGHT - int(50 * $value);
    }
    else {
      $y0 = $GRAPH_HEIGHT - int(50 + ($value-1) * (400/3));
    }
    my $y1;
    ## print "8888: $i, $value<br>";
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( $x0 == 426 ) {
      $mid_value = $y0;
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

  my $x0 = 401 + 30 + 25;
  my $x1 = $x0;
  ## my $y0 = $GRAPH_HEIGHT - $mid_value;
  my $y0 = $mid_value;
  my $y1 = $GRAPH_HEIGHT;
  $im->line($x0, $y0, $x1, $y1, $COLORS{lightblue});

  my $x0 = 0 + 30;
  my $x1 = $GRAPH_WIDTH + 30;
  my $y0 = $GRAPH_HEIGHT - int(50 * 1);
  my $y1 = $y0;
  $im->line($x0, $y0, $x1, $y1, $COLORS{white});


  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;
  if( $left_flag == 1 ) {
    my $x0 = 800/$CHOOSE_WAY - $current_pos;
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  elsif( $right_flag == 1 ) {
    my $x0 = 800 - (($current_pos + 800/$CHOOSE_WAY) -  (@{ $binned_data_high_detail{$chr} } - 2));
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
  }
  else {
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return ($cache_id);
}

######################################################################
sub Graph_high_detail_high {
  my ($chr, $pos, $CHOOSE_WAY, $max) = @_;

use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  ## my $GRAPH_HEIGHT        = 50 + 100 * ( int($detail_max) + 2 );
  my $GRAPH_HEIGHT        = 200;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * 800; 
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 100;
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
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  my $x0 = 0;
  my $y0 = $GRAPH_HEIGHT;
  $im->string(gdSmallFont, $x0, $y0, 0, $COLORS{red});
  $y0 = $GRAPH_HEIGHT - int(50 * ($max/($max + 1)) * 4);
  $im->string(gdSmallFont, $x0, $y0, $max, $COLORS{red});
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*100/$CHOOSE_WAY;
  ## my $current_pos = $pos*100/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  for (my $i = 1; $i < @{ $binned_data_high_detail{$chr} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }

    if( not defined  $binned_data_high_detail{$chr}[$i] ) {
      next;
    }

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data_high_detail{$chr}[$i]);

    if( ($current_pos - 800/$CHOOSE_WAY <= 0) and ($i == 1) ) {
    
      $left_flag = 1;
    }
    elsif ( $i == $current_pos - 800/$CHOOSE_WAY ) {
      $pos_start = $start_pos;
    }

    my $len = @{ $binned_data_high_detail{$chr} } - 1;
    if( ($current_pos + 800/$CHOOSE_WAY >= $len) and ($i == $len - 1) ) {
      $pos_end = $start_pos;
      $right_flag = 1;
    } 
    elsif( $i == $current_pos + 800/$CHOOSE_WAY ) {
      $pos_end = $start_pos;
    }

    if( $current_pos == $i ) {
      $pos_click = $start_pos;
    }

    my $tmp_i = $i - ($current_pos - 800/$CHOOSE_WAY);

    my $x0 = $PIX_PER_INTERVAL * ($tmp_i - 1);
    my $x1 = $PIX_PER_INTERVAL * $tmp_i;
    my $y0;
    $y0 = $GRAPH_HEIGHT - int(50 * ($last_val/($max + 1)) * 4);
    my $y1;
    ## print "8888: $i, $value<br>";
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( $x0 == 426 ) {
      $mid_value = $y0;
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

  my $x0 = 401 + 30 + 25;
  my $x1 = $x0;
  ## my $y0 = $GRAPH_HEIGHT - $mid_value;
  my $y0 = $mid_value;
  my $y1 = $GRAPH_HEIGHT;
  $im->line($x0, $y0, $x1, $y1, $COLORS{lightblue});

  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;
  if( $left_flag == 1 ) {
    my $x0 = 800/$CHOOSE_WAY - $current_pos;
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  elsif( $right_flag == 1 ) {
    my $x0 = 800 - (($current_pos + 800/$CHOOSE_WAY) -  (@{ $binned_data_high_detail{$chr} } - 2));
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
  }
  else {
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return ($cache_id);
}

######################################################################
sub Graph_high_detail_low {
  my ($chr, $pos, $CHOOSE_WAY, $max) = @_;

use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  my $GRAPH_HEIGHT        = 400 + 50;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * 800; 
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 100;
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
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT, 0, $COLORS{black});
  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT - 400, 1, $COLORS{black});
  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT - 450, 2, $COLORS{black});
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*100/$CHOOSE_WAY;
  ## my $current_pos = $pos*100/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  for (my $i = 1; $i < @{ $binned_data_high_detail{$chr} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }

    if( not defined  $binned_data_high_detail{$chr}[$i] ) {
      next;
    }

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data_high_detail{$chr}[$i]);

    if( ($current_pos - 800/$CHOOSE_WAY <= 0) and ($i == 1) ) {
    
      $left_flag = 1;
    }
    elsif ( $i == $current_pos - 800/$CHOOSE_WAY ) {
      $pos_start = $start_pos;
    }

    my $len = @{ $binned_data_high_detail{$chr} } - 1;
    if( ($current_pos + 800/$CHOOSE_WAY >= $len) and ($i == $len - 1) ) {
      $pos_end = $start_pos;
      $right_flag = 1;
    } 
    elsif( $i == $current_pos + 800/$CHOOSE_WAY ) {
      $pos_end = $start_pos;
    }

    if( $current_pos == $i ) {
      $pos_click = $start_pos;
    }

    my $tmp_i = $i - ($current_pos - 800/$CHOOSE_WAY);

    my $x0 = $PIX_PER_INTERVAL * ($tmp_i - 1);
    my $x1 = $PIX_PER_INTERVAL * $tmp_i;
    my $y0;
    $y0 = $GRAPH_HEIGHT - int(400 * $value);
    my $y1;
    ## print "8888: $i, $value<br>";
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( $x0 == 426 ) {
      $mid_value = $y0;
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

  my $x0 = 401 + 30 + 25;
  my $x1 = $x0;
  ## my $y0 = $GRAPH_HEIGHT - $mid_value;
  my $y0 = $mid_value;
  my $y1 = $GRAPH_HEIGHT;
  $im->line($x0, $y0, $x1, $y1, $COLORS{lightblue});

  my $x0 = 0 + 30;
  my $x1 = $GRAPH_WIDTH + 30;
  my $y0 = $GRAPH_HEIGHT - 400;
  my $y1 = $y0;
  $im->line($x0, $y0, $x1, $y1, $COLORS{white});


  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;
  if( $left_flag == 1 ) {
    my $x0 = 800/$CHOOSE_WAY - $current_pos;
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  elsif( $right_flag == 1 ) {
    my $x0 = 800 - (($current_pos + 800/$CHOOSE_WAY) -  (@{ $binned_data_high_detail{$chr} } - 2));
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
  }
  else {
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return ($cache_id);
}

######################################################################
sub Graph_low_detail {
  my ($chr, $pos, $CHOOSE_WAY) = @_;

use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  ## my $GRAPH_HEIGHT        = 200 * 100/$CHOOSE_WAY;
  my $GRAPH_HEIGHT        = 50 + 400;
  ## my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * @{ $binned_data_low_detail{$chr} };
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * 800; 
  ## my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 30;
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 100;
  ## my $IMAGE_WIDTH         = $GRAPH_WIDTH  + 30;
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
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT, 0, $COLORS{black});
  for (my $y0 = $GRAPH_HEIGHT - 50; $y0 >= 0; $y0 = $y0 - int(400/3)) {
    my $x0 = 0;
    $im->string(gdSmallFont, $x0, $y0, int( 1 + ($GRAPH_HEIGHT - $y0)/int(400/3)), $COLORS{black});
  }
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*100/$CHOOSE_WAY;
  ## my $current_pos = $pos*100/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  for (my $i = 1; $i < @{ $binned_data_low_detail{$chr} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }

    if( not defined  $binned_data_low_detail{$chr}[$i] ) {
      next;
    }

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data_low_detail{$chr}[$i]);

    if( ($current_pos - 800/$CHOOSE_WAY <= 0) and ($i == 1) ) {
    
      $left_flag = 1;
    }
    elsif ( $i == $current_pos - 800/$CHOOSE_WAY ) {
      $pos_start = $start_pos;
    }

    my $len = @{ $binned_data_low_detail{$chr} } - 1;
    if( ($current_pos + 800/$CHOOSE_WAY >= $len) and ($i == $len - 1) ) {
      $pos_end = $start_pos;
      $right_flag = 1;
    } 
    elsif( $i == $current_pos + 800/$CHOOSE_WAY ) {
      $pos_end = $start_pos;
    }

    if( $current_pos == $i ) {
      $pos_click = $start_pos;
    }

    my $tmp_i = $i - ($current_pos - 800/$CHOOSE_WAY);

    my $x0 = $PIX_PER_INTERVAL * ($tmp_i - 1);
    my $x1 = $PIX_PER_INTERVAL * $tmp_i;
    my $y0;
    if( $value <= 1 ) {
      $y0 = $GRAPH_HEIGHT - int(50 * $value);
    }
    else {
      $y0 = $GRAPH_HEIGHT - int(50 + ($value-1) * (400/3));
    }
    my $y1;
    ## print "8888: $i, $value<br>";
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( $x0 == 426 ) {
      $mid_value = $y0;
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

  my $x0 = 401 + 30 + 25;
  my $x1 = $x0;
  ## my $y0 = $GRAPH_HEIGHT - $mid_value;
  my $y0 = $mid_value;
  my $y1 = $GRAPH_HEIGHT;
  $im->line($x0, $y0, $x1, $y1, $COLORS{lightblue});

  my $x0 = 0 + 30;
  my $x1 = $GRAPH_WIDTH + 30;
  my $y0 = $GRAPH_HEIGHT - int(50 * 1);
  my $y1 = $y0;
  $im->line($x0, $y0, $x1, $y1, $COLORS{white});


  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;
  if( $left_flag == 1 ) {
    my $x0 = 800/$CHOOSE_WAY - $current_pos;
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  elsif( $right_flag == 1 ) {
    my $x0 = 800 - (($current_pos + 800/$CHOOSE_WAY) -  (@{ $binned_data_low_detail{$chr} } - 2));
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
  }
  else {
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return ($cache_id);
}

######################################################################
sub Graph_low_detail_high {
  my ($chr, $pos, $CHOOSE_WAY, $max) = @_;

use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  ## my $GRAPH_HEIGHT        = 50 + 100 * ( int($detail_max) + 2 );
  my $GRAPH_HEIGHT        = 200;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * 800; 
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 100;
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
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  my $x0 = 0;
  my $y0 = $GRAPH_HEIGHT;
  $im->string(gdSmallFont, $x0, $y0, 0, $COLORS{red});
  $y0 = $GRAPH_HEIGHT - int(50 * ($max/($max + 1)) * 4);
  $im->string(gdSmallFont, $x0, $y0, $max, $COLORS{red});
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*100/$CHOOSE_WAY;
  ## my $current_pos = $pos*100/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  for (my $i = 1; $i < @{ $binned_data_low_detail{$chr} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }

    if( not defined  $binned_data_low_detail{$chr}[$i] ) {
      next;
    }

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data_low_detail{$chr}[$i]);

    if( ($current_pos - 800/$CHOOSE_WAY <= 0) and ($i == 1) ) {
    
      $left_flag = 1;
    }
    elsif ( $i == $current_pos - 800/$CHOOSE_WAY ) {
      $pos_start = $start_pos;
    }

    my $len = @{ $binned_data_low_detail{$chr} } - 1;
    if( ($current_pos + 800/$CHOOSE_WAY >= $len) and ($i == $len - 1) ) {
      $pos_end = $start_pos;
      $right_flag = 1;
    } 
    elsif( $i == $current_pos + 800/$CHOOSE_WAY ) {
      $pos_end = $start_pos;
    }

    if( $current_pos == $i ) {
      $pos_click = $start_pos;
    }

    my $tmp_i = $i - ($current_pos - 800/$CHOOSE_WAY);

    my $x0 = $PIX_PER_INTERVAL * ($tmp_i - 1);
    my $x1 = $PIX_PER_INTERVAL * $tmp_i;
    my $y0;
    $y0 = $GRAPH_HEIGHT - int(50 * ($last_val/($max + 1)) * 4);
    my $y1;
    ## print "8888: $i, $value<br>";
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( $x0 == 426 ) {
      $mid_value = $y0;
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

  my $x0 = 401 + 30 + 25;
  my $x1 = $x0;
  ## my $y0 = $GRAPH_HEIGHT - $mid_value;
  my $y0 = $mid_value;
  my $y1 = $GRAPH_HEIGHT;
  $im->line($x0, $y0, $x1, $y1, $COLORS{lightblue});

  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;
  if( $left_flag == 1 ) {
    my $x0 = 800/$CHOOSE_WAY - $current_pos;
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  elsif( $right_flag == 1 ) {
    my $x0 = 800 - (($current_pos + 800/$CHOOSE_WAY) -  (@{ $binned_data_low_detail{$chr} } - 2));
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
  }
  else {
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return ($cache_id);
}

######################################################################
sub Graph_low_detail_low {
  my ($chr, $pos, $CHOOSE_WAY, $max) = @_;

use GD;
 
  my $STYLE               = "histogram"; # "line graph";    ## "histogram"
  my $PIX_PER_INTERVAL    = 1;
  if ($STYLE eq "line graph" && $PIX_PER_INTERVAL < 2) {
    die "for line graph, must have pixels per interval >= 2";
  }
  my $GRAPH_HEIGHT        = 400 + 50;
  my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * 800; 
  my $IMAGE_HEIGHT        = $GRAPH_HEIGHT + 100;
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
 
  $im->filledRectangle (
    0+30, 0, $GRAPH_WIDTH+30, $GRAPH_HEIGHT,
    $COLORS{black}
  );

  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT, 0, $COLORS{black});
  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT - 400, 1, $COLORS{black});
  $im->string(gdSmallFont, 0, $GRAPH_HEIGHT - 450, 2, $COLORS{black});
 
  my $last_val;
  my ($pos_start, $pos_end, $pos_click);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*100/$CHOOSE_WAY;
  ## my $current_pos = $pos*100/$CHOOSE_WAY;
  my $current_pos_start;
  my ($pre_x0, $pre_y0);
  my $mid_value;
  for (my $i = 1; $i < @{ $binned_data_low_detail{$chr} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }

    if( not defined  $binned_data_low_detail{$chr}[$i] ) {
      next;
    }

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data_low_detail{$chr}[$i]);

    if( ($current_pos - 800/$CHOOSE_WAY <= 0) and ($i == 1) ) {
    
      $left_flag = 1;
    }
    elsif ( $i == $current_pos - 800/$CHOOSE_WAY ) {
      $pos_start = $start_pos;
    }

    my $len = @{ $binned_data_low_detail{$chr} } - 1;
    if( ($current_pos + 800/$CHOOSE_WAY >= $len) and ($i == $len - 1) ) {
      $pos_end = $start_pos;
      $right_flag = 1;
    } 
    elsif( $i == $current_pos + 800/$CHOOSE_WAY ) {
      $pos_end = $start_pos;
    }

    if( $current_pos == $i ) {
      $pos_click = $start_pos;
    }

    my $tmp_i = $i - ($current_pos - 800/$CHOOSE_WAY);

    my $x0 = $PIX_PER_INTERVAL * ($tmp_i - 1);
    my $x1 = $PIX_PER_INTERVAL * $tmp_i;
    my $y0;
    $y0 = $GRAPH_HEIGHT - int(400 * $value);
    my $y1;
    ## print "8888: $i, $value<br>";
    if ($STYLE eq "line graph") {
      $y1 = $GRAPH_HEIGHT - int(50 * $value);
    } else {
      $y1 = $GRAPH_HEIGHT;
    }
    if( $x0 == 426 ) {
      $mid_value = $y0;
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

  my $x0 = 401 + 30 + 25;
  my $x1 = $x0;
  ## my $y0 = $GRAPH_HEIGHT - $mid_value;
  my $y0 = $mid_value;
  my $y1 = $GRAPH_HEIGHT;
  $im->line($x0, $y0, $x1, $y1, $COLORS{lightblue});

  my $x0 = 0 + 30;
  my $x1 = $GRAPH_WIDTH + 30;
  my $y0 = $GRAPH_HEIGHT - 400;
  my $y1 = $y0;
  $im->line($x0, $y0, $x1, $y1, $COLORS{white});


  my $increase = ($pos_end - $pos_start) / 10;
  my $count = 0;
  if( $left_flag == 1 ) {
    my $x0 = 800/$CHOOSE_WAY - $current_pos;
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  elsif( $right_flag == 1 ) {
    my $x0 = 800 - (($current_pos + 800/$CHOOSE_WAY) -  (@{ $binned_data_low_detail{$chr} } - 2));
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
  }
  else {
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 401+30+25, $GRAPH_HEIGHT+30, int($pos_click), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(401+30+25, $y0, 401+30+25, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  ## $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
  ##   $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  my $cache_id = WriteDKToCache($im->png, $chr);
  return ($cache_id);
}

######################################################################
1;
