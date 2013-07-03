#####################################################################
# DKViews.pm
######################################################################

use strict;
use DBI;
use CGAPConfig;
use Cache;
use Paging;

use constant ORACLE_LIST_LIMIT => 500;

use constant WINDOW_SIZE => 200;
use constant BIN_SIZE => 100;
my (%window_value);
my (@start, @end, @window_val, @tag_num);
my (%binned_data);

my $BASE;

my $dk_cache = new Cache(CACHE_ROOT, DK_CACHE_PREFIX);
my $CACHE_FAIL = 0;

######################################################################
sub UploadExperimentalFile_1 {
  my ($base, $org, $filedata) = @_;
 
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
 
  my @tempArray;
  if( $filedata =~ /\r/ ) {
    @tempArray = split "\r", $filedata;
  }
  else {
    @tempArray = split "\n", $filedata;
  }
 
  for (my $t = 0; $t < @tempArray; $t++ ) {
    $tempArray[$t] =~  s/\s//g;
    if ($tempArray[$t] eq "") {
      next;
    }
    else {
      push @all_lines, $tempArray[$t];
      $tags{$tempArray[$t]} = 1;
    }
  }
 
  $count = @all_lines;
  if ( $count > 200000 ) {
    if( $email ne "" ) {
      my $id = write_upload_file(\@all_lines, $email, $order, $org);
      if( $id eq "" ) {
        return "There is a error in the process.";
      }
      else {
        return "Your file has been uploaded and you will receive " .
               "an email ($email) within five days for your result. " .
               "Otherwise please contace us, your upload file id is $id";
      }
    }
    else {
      return "Your file has more than 200000 tags, Please fill email address.";
    }
  }
 
}

######################################################################
sub DKView_1 {
  my ($base) = @_;
 
  ## my @mapped_data;
  my $exp_f = "/share/content/CGAP/SAGE/data/DK_experimental.txt";
  my $map_f = "/share/content/CGAP/SAGE/data/dkmap.dat";
  my $mapped_f = "/share/content/CGAP/SAGE/data/mapped.txt";
  my %exp;
  my %freq;

  my $window_size = WINDOW_SIZE;
  my $bin_size = BIN_SIZE;
 
  open (OUT, ">$mapped_f") or die "Can not open $mapped_f\n";

  open(INF, $exp_f) or die "cannot open $exp_f";
  while (<INF>) {
    s/[\r\n]+//;
    my ($tag, $freq) = split /\t/;
    $exp{$tag} += $freq;
  }
  close INF;

  open(INF, $map_f) or die "cannot open $map_f";
  while (<INF>) {
    s/[\r\n]+//;
    my ($tag, $chr, $pos, $strand, $tag_num) = split /\t/;
    my $freq;
    if (defined $exp{$tag}) {
      $freq = $exp{$tag};
    } else {
      $freq = 0;
    }
    print OUT "$_\t$freq\n";
  }
  close INF;

  close OUT;

  ## print "8888: call window_dk \n";

  return window_dk($window_size, $bin_size);

}

######################################################################
 
sub window_dk {
  my ( $window_size, $bin_size ) = @_;

  my $mapped_data_f = "/share/content/CGAP/SAGE/data/mapped.txt";

  my $window_info_f = "/share/content/CGAP/SAGE/data/window_info.txt";
  open(OUT, ">$window_info_f") or die "Can not open $window_info_f \n";

  my ($tag, $chr, $pos, $strand, $tag_num, $freq);
  my (%mapped_data, $n_virtual_tags, $sum_freq);
  my (%freq);
  my @chr_order = ("1", "2", "3", "4", "5", "6", "7", "8", "9",
      "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
      "20", "21", "22", "X", "Y");
   
  if ($window_size % 2 != 0) {
    $window_size++;
    print STDERR "increasing window size by 1 to $window_size\n";
  }
  my $half_window = $window_size / 2;
   
  open(INF, $mapped_data_f) or die "cannot open $mapped_data_f";
  while (<INF>) {
    chop;
    ($tag, $chr, $pos, $strand, $tag_num, $freq) = split /\t/;
    push @{ $mapped_data{$chr} }, $_;
    push @{ $freq{$chr} }, $freq;
    $sum_freq += $freq;
    $n_virtual_tags++;
  }
  close INF;
   
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
   
  ## print "average_freq for $sum_freq tags over $n_virtual_tags = " .
  ##   sprintf("%.2f", $overall_avg) . "\n";
  for $chr (@chr_order) {
    for (my $tag_num = 0; $tag_num < @{ $freq{$chr} }; $tag_num++) {
      $window_value{$chr}[$tag_num] = ComputeWindow($chr, $tag_num, $half_window, \%n_virtual_tags_per_chr, $window_size, \%freq);
    }
  }
  for my $chr (@chr_order) {
    for (my $i = 0; $i < @{ $window_value{$chr} }; $i++) {
      my $value = sprintf("%.2f", $window_value{$chr}[$i]);
      my $f = sprintf("%.2f", $freq{$chr}[$i]);
      ## print "$mapped_data{$chr}[$i]\t$f\t$value\n";
      print OUT "$mapped_data{$chr}[$i]\t$f\t$value\n";
    }
  }

  close OUT;

  undef %mapped_data;
  undef %freq;
  ## print "8888: call pick_nth_tag \n";
  return pick_nth_tag($bin_size);
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
      return (
          $window_value{$chr}[$tag_num - 1] * ($window_size + 1) -
          $freq{$chr}[$tag_num - $half_window - 1] +
          $freq{$chr}[$tag_num + $half_window]
        ) / ($window_size + 1);
    }
  }
 
  ## it's one end or the other
 
  my $sum;
  for (my $i = $tag_num - $j; $i <= $tag_num + $j; $i++) {
    $sum += $freq{$chr}[$i];
  }
  ## print "8888 sum: $tag_num, $j, $sum \n";
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
 
  my ($bin_size) = @_;
 
  my $window_info_f = "/share/content/CGAP/SAGE/data/window_info.txt";
  open(IN, "$window_info_f") or die "Can not open $window_info_f \n";
 
  ## my @window_dk_data = @{$window_dk_data_ref};
  my ($n);
  my ($tag, $chr, $pos, $strand, $tag_num, $freq, $normal_freq, $window_val);
  my ($last_chr);
  my (@lines, %chr_2_image_id);
  my (@image_map);
  my @chr_order = ("1", "2", "3", "4", "5", "6", "7", "8", "9",
      "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
      "20", "21", "22", "X", "Y");
  while(<IN>) {
    chop;
    ($tag, $chr, $pos, $strand, $tag_num, $freq, $normal_freq, $window_val) =
        split /\t/, $_;
    if ($last_chr && $last_chr ne $chr) {
      DoBin($last_chr, $n, $bin_size);
      $n = 0;
    }
    $last_chr = $chr;
    $n++;
    push @window_val, $window_val;
    push @start, $pos;
    if ($n % $bin_size == 0) {
      DoBin($chr, $n, $bin_size);
    }
  }
 
  close IN;
 
  if ($n % $bin_size > 0) {
    DoBin($chr, $n, $bin_size);
  }
 
  for my $chr (@chr_order) {
    my $chrmapname = "chrmap" . $chr;
    push @image_map, "<map name=\"$chrmapname\">";
    ## print "8888: $chr \n";
    $chr_2_image_id{$chr} =  Graph($chr, \@image_map);
    ## $chr_2_image_id{$chr} =  Graph($chr, \@image_map);
    ## print "8888: $chr_2_image_id{$chr}<br>";
    ## push @{ $image_map{chr} }, "</map>";
    push @image_map, "</map>";
  }
 
  push @lines, "<html>\n";
##   push @lines, "<center>\n";
##   push @lines, "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n";
  for my $chr (@chr_order) {
    my $id = $chr_2_image_id{$chr};
    my $chrmapname = "chrmap" . $chr;
    ## push @lines, "<img src=\"DKImage?CACHE=$id&CHR=$chr\" border=0\"><br>";
    push @lines, "<img src=\"DKImage?CACHE=$id&CHR=$chr\" border=0 usemap=\"#$chrmapname\"><br>";
    ## push @lines, "<tr><td><img src=\"DKImage?CACHE=$id&CHR=$chr\" border=0></td>
## </tr>\n";
    ## print "DKImage?CACHE=$id&CHR=$chr<br>";
  }
    push @lines, @image_map;
##  push @lines, "</table>\n";
##  push @lines, "</center>\n";
  push @lines, "</html>\n";
 
  return (join "", @lines);
}
 
######################################################################
sub DoBin {
  my ($chr, $n, $bin_size) = @_;
 
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
  undef @start;
  undef @end;
  undef @window_val;
}
 
######################################################################
sub Graph {
  my ($chr, $image_map_ref) = @_;
 
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
      "href=\"DKViewDetail?CHR=$chr&POS=$i\" >";

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

sub DKViewDetail_1 {
  my ($base, $chr, $pos) = @_;
 
  ## my @mapped_data;
  my $exp_f = "/share/content/CGAP/SAGE/data/DK_experimental.txt";
  my $map_f = "/share/content/CGAP/SAGE/data/dkmap.dat";
  my $mapped_f = "/share/content/CGAP/SAGE/data/mapped.txt";
  my %exp;
  my %freq;

  my $window_size = WINDOW_SIZE;
  my $bin_size = BIN_SIZE;
 
  return window_dk_detail($window_size, $bin_size, $chr, $pos);

}

######################################################################
 
sub window_dk_detail {
  my ( $window_size, $bin_size, $chr_in, $pos_in ) = @_;
  my $N_VIRTUAL_TAGS = 401;
  my $mapped_data_f = "/share/content/CGAP/SAGE/data/mapped.txt";

  my $window_info_f = "/share/content/CGAP/SAGE/data/window_info_detail.txt";
  open(OUT, ">$window_info_f") or die "Can not open $window_info_f \n";

  my ($tag, $chr, $pos, $strand, $tag_num, $freq);
  my (%mapped_data, $n_virtual_tags, $sum_freq);
  my (%freq);
  my @chr_order = ("1", "2", "3", "4", "5", "6", "7", "8", "9",
      "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
      "20", "21", "22", "X", "Y");
   
  if ($window_size % 2 != 0) {
    $window_size++;
    print STDERR "increasing window size by 1 to $window_size\n";
  }
  my $half_window = $window_size / 2;
   
  open(INF, $mapped_data_f) or die "cannot open $mapped_data_f";
  while (<INF>) {
    chop;
    ($tag, $chr, $pos, $strand, $tag_num, $freq) = split /\t/;
    if( $chr eq $chr_in ) {
      push @{ $mapped_data{$chr} }, $_;
      push @{ $freq{$chr} }, $freq;
    }
    $sum_freq += $freq;
    $n_virtual_tags++;
  }
  close INF;
   
  #my $overall_avg = sprintf("%.3f", $sum_freq/$n_virtual_tags + 0.0005);
  my $overall_avg = $sum_freq/$n_virtual_tags;
  my %n_virtual_tags_per_chr;
  $n_virtual_tags_per_chr{$chr_in} = @{ $freq{$chr_in} };
  ## $n_virtual_tags_per_chr{$chr_in} = $N_VIRTUAL_TAGS;
   
  for my $f (@{ $freq{$chr_in} }) {
    $f = $f / $overall_avg;
  }
   
  ## print "average_freq for $sum_freq tags over $n_virtual_tags = " .
  ##   sprintf("%.2f", $overall_avg) . "\n";
  for (my $tag_num = 0; $tag_num < @{ $freq{$chr_in} }; $tag_num++) {
    $window_value{$chr_in}[$tag_num] = ComputeWindow_detail($chr_in, $tag_num, $half_window, \%n_virtual_tags_per_chr, $window_size, \%freq);
  }

  for (my $i = 0; $i < @{ $window_value{$chr_in} }; $i++) {
    my $value = sprintf("%.2f", $window_value{$chr_in}[$i]);
    my $f = sprintf("%.2f", $freq{$chr_in}[$i]);
    ## print "$mapped_data{$chr}[$i]\t$f\t$value\n";
    print OUT "$mapped_data{$chr_in}[$i]\t$f\t$value\n";
  }

  close OUT;

  undef %mapped_data;
  undef %freq;
  ## print "8888: call pick_nth_tag \n";
  return pick_nth_tag_detail($bin_size, $chr_in, $pos_in);
}

 
######################################################################
sub ComputeWindow_detail {
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
      return (
          $window_value{$chr}[$tag_num - 1] * ($window_size + 1) -
          $freq{$chr}[$tag_num - $half_window - 1] +
          $freq{$chr}[$tag_num + $half_window]
        ) / ($window_size + 1);
    }
  }
 
  ## it's one end or the other
 
  my $sum;
  for (my $i = $tag_num - $j; $i <= $tag_num + $j; $i++) {
    $sum += $freq{$chr}[$i];
  }
  ## print "8888 sum: $tag_num, $j, $sum \n";
  return $sum / (($j * 2) + 1);
}
 
######################################################################

sub pick_nth_tag_detail {
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
 
  my ($bin_size, $chr_in, $pos_in) = @_;
  my $CHOOSE_WAY = 2;
 
  my $window_info_f = "/share/content/CGAP/SAGE/data/window_info_detail.txt";
  open(IN, "$window_info_f") or die "Can not open $window_info_f \n";
 
  ## my @window_dk_data = @{$window_dk_data_ref};
  my ($n);
  my ($tag, $chr, $pos, $strand, $tag_num, $freq, $normal_freq, $window_val);
  my ($last_chr);
  my (@lines, $chr_2_image_id);
  my (@image_map);
  my @chr_order = ("1", "2", "3", "4", "5", "6", "7", "8", "9",
      "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
      "20", "21", "22", "X", "Y");
  while(<IN>) {
    chop;
    ($tag, $chr, $pos, $strand, $tag_num, $freq, $normal_freq, $window_val) =
        split /\t/, $_;
    if( $chr ne $chr_in ) {
      next;
    }
    if ($last_chr && $last_chr ne $chr) {
      DoBin_detail($last_chr, $n, $bin_size);
      $n = 0;
    }
    $last_chr = $chr;
    $n++;
    push @window_val, $window_val;
    push @start, $pos;
    ## if ($n % $bin_size == 0) {
    if ($n % $CHOOSE_WAY == 0) {
      DoBin_detail($chr_in, $n, $bin_size);
    }
  }
 
  close IN;
 
  if ($n % $bin_size > 0) {
    DoBin_detail($chr_in, $n, $bin_size);
  }
 
  $chr_2_image_id =  Graph_detail($chr_in, $pos_in, $CHOOSE_WAY);
  ## return $chr_2_image_id;
 
  push @lines, "<img src=\"DKImage?CACHE=$chr_2_image_id&CHR=$chr_in\" border=0>";
 
  return (join "", @lines);
}
 
######################################################################
sub DoBin_detail {
  my ($chr, $n, $bin_size) = @_;
 
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
  undef @start;
  undef @end;
  undef @window_val;
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
  ## my $GRAPH_WIDTH         = $PIX_PER_INTERVAL * @{ $binned_data{$chr} };
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
  my ($pos_start, $pos_end);
  my ($left_flag, $right_flag);
  my $current_pos = ($pos-1)*100/$CHOOSE_WAY;
  my ($pre_x0, $pre_y0);
  for (my $i = 1; $i < @{ $binned_data{$chr} } - 1; $i++ ) {
    if( $i < $current_pos - 800/$CHOOSE_WAY or $i > $current_pos + 800/$CHOOSE_WAY ) {
      next;
    }

    if( not defined  $binned_data{$chr}[$i] ) {
      next;
    }

    my ($bin_num, $chr, $start_pos, $end_pos, $start_tag, $end_tag, $value)
        = split("\t", $binned_data{$chr}[$i]);

    if( ($current_pos - 800/$CHOOSE_WAY <= 0) and ($i == 1) ) {
      $pos_start = $start_pos;
      $left_flag = 1;
    }
    elsif ( $i == $current_pos - 800/$CHOOSE_WAY ) {
      $pos_start = $start_pos;
    }

    my $len = @{ $binned_data{$chr} } - 1;
    if( ($current_pos + 800/$CHOOSE_WAY >= $len) and ($i == $len - 1) ) {
      $pos_end = $start_pos;
      $right_flag = 1;
    } 
    elsif( $i == $current_pos + 800/$CHOOSE_WAY ) {
      $pos_end = $start_pos;
    }

    my $tmp_i = $i - ($current_pos - 800/$CHOOSE_WAY);

    ## print "8888: $tmp_i<br>";
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
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  elsif( $right_flag == 1 ) {
    my $x0 = 800 - (($current_pos + 800/$CHOOSE_WAY) -  (@{ $binned_data{$chr} } - 2));
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, $x0+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line($x0+30, $y0, $x0+30, $y1, $COLORS{black});
  }
  else {
    $im->string(gdSmallFont, 0+30, $GRAPH_HEIGHT+30, int($pos_start), $COLORS{black});
    $im->string(gdSmallFont, 800+30, $GRAPH_HEIGHT+30, int($pos_end), $COLORS{black});
    $y0 = $GRAPH_HEIGHT;
    $y1 = $y0 + 25;
    $im->line(0+30, $y0, 0+30, $y1, $COLORS{black});
    $im->line(800+30, $y0, 800+30, $y1, $COLORS{black});
  }
  $im->string(gdSmallFont, 0+4, $GRAPH_HEIGHT+30, "bp:", $COLORS{black});

  ## for ( my $x=0; $x<=800; $x = $x+8 ) {
  ##   $x0 = $x+30;
  ##   $x1 = $x0;
  ##   if( $x % 80 == 0 ) {
  ##     $y1 = $y0 - 10;
  ##   }
  ##   elsif( $x % 40 == 0 ) {
  ##     $y1 = $y0 - 7;
  ##   }
  ##   else {
  ##     $y1 = $y0 - 3;
  ##   }
  ##   $im->line($x0, $y0, $x1, $y1, $COLORS{black});
  ## }

  $im->string(gdLargeFont, 0+30, $GRAPH_HEIGHT+70, "Chromosome " . $chr,
    $COLORS{black});
 
  ## return (join "<br", @tmp);
  ## print "8888: call WriteDKGEToCache <br>";
  return WriteDKToCache($im->png, $chr)
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
1;
