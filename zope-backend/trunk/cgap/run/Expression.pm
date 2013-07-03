#!/usr/local/bin/perl

######################################################################
# GenomeExpression.pm
#
######################################################################

use strict;
use DBI;
use CGAPConfig;
use Bayesian;
use Cache;
use GD;

my $DENOM       = 200000;
my $BP_SCALE    = 100000;

my $IMAGE_HEIGHT        = 1800;
##my $IMAGE_WIDTH  = 800;
my $IMAGE_WIDTH         = 800;
my $ZOOMED_AXIS_LENGTH  = 1600;  ## i.e., 800 pixels * SCALED_BPS_TO_PIXEL
my $VERT_MARGIN         = 45;
my $GENE_BAR_CONSTANT   = 10;
my $SCALED_BPS_TO_PIXEL = 2;
my %COLORS;

my (%vn_lib_count, %vn_seq_count, %code2tiss, %tiss2code);

my $BASE;
##my $cache = new Cache(CACHE_ROOT, GENOME_CACHE_PREFIX);
my $cache = new Cache(CACHE_ROOT, "GE");

if (-d "/app/oracle/product/8.1.7") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.7";
} else {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.6";
}

######################################################################
sub numerically { $a <=> $b ;}

######################################################################
use constant LN2 => log(2);
use constant LN10 => log(10);

sub log2 { return log(shift)/LN2; }
sub log10 { return log(shift)/LN10; }


######################################################################
sub InitializeImage {

  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);
 
  # allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
  $COLORS{white}       = $im->colorAllocate(255,255,255);
  $COLORS{black}       = $im->colorAllocate(0,0,0);
  $COLORS{red}         = $im->colorAllocate(255,0,0);
#  $COLORS{blue}        = $im->colorAllocate(0,0,255);
  $COLORS{lightblue}   = $im->colorAllocate(173,216,230);
#  $COLORS{green}       = $im->colorAllocate(0,128,0);
  $COLORS{yellow}      = $im->colorAllocate(255,255,0);
#  $COLORS{olive}       = $im->colorAllocate(128,128,0);
#  $COLORS{darkred}     = $im->colorAllocate(139,0,0);
#  $COLORS{violet}      = $im->colorAllocate(238,130,238);
#  $COLORS{yellowgreen} = $im->colorAllocate(154,205,50);
#  $COLORS{darksalmon}  = $im->colorAllocate(233,150,122);
#  $COLORS{darkblue}    = $im->colorAllocate(0,0,139);
#  $COLORS{darkgreen}   = $im->colorAllocate(0,100,0);
#  $COLORS{purple}      = $im->colorAllocate(128,0,128);
##  $COLORS{gray}        = $im->colorAllocate(128,128,128);
##  $COLORS{lightgray}   = $im->colorAllocate(211,211,211);

  $COLORS{gray}        = $im->colorAllocate(200,200,200);
  $COLORS{mediumgray}  = $im->colorAllocate(220,220,220);
  $COLORS{lightgray}   = $im->colorAllocate(240,240,240);

  $COLORS{gneg}        = $COLORS{white};
  $COLORS{gpos25}      = $COLORS{lightgray};
  $COLORS{gpos50}      = $COLORS{mediumgray};
  $COLORS{gpos75}      = $COLORS{gray};
  $COLORS{gpos100}     = $COLORS{black};
  $COLORS{stalk}       = $COLORS{white};

  $im->transparent($COLORS{white});
##  $im->interlaced("true");

  return $im;
}

######################################################################
sub DrawGrid {
  my ($im, $scaled_start, $scaled_end, $zoomscale, $org, $chr, $tissue,
      $src, $filter, $exp_fold, $zfold, $zlevel, $image_map) = @_;

  my $vert_length = sprintf("%d",
      ($scaled_end - $scaled_start) * $zoomscale);

  ## origins
  my $x0 = $IMAGE_WIDTH / 2;
  my $y0 = TranslatePixelAxis($VERT_MARGIN, 0),
  my $y1 = TranslatePixelAxis($VERT_MARGIN, $vert_length /
      $SCALED_BPS_TO_PIXEL);

  my $GRID_DEGREES = 8;

  my ($x1);


  $im->filledRectangle (
      $x0,
      $y0,
      $x0,
      $y1,
      $COLORS{black}
  );

  for (my $i = 1; $i < $GRID_DEGREES; $i++) {

    $x1 = TranslatePixelAxis($x0, sprintf("%d",
          2 * $i * $GENE_BAR_CONSTANT));
    $im->filledRectangle (
        $x1,
        $y0,
        $x1,
        $y1,
        $COLORS{white}
    );
    $im->string(gdSmallFont, $x1 - 8, 30, "+" . (2 * $i), $COLORS{black});

    $x1 = TranslatePixelAxis($x0, sprintf("%d",
          -2 * $i * $GENE_BAR_CONSTANT));
    $im->filledRectangle (
        $x1,
        $y0,
        $x1,
        $y1,
        $COLORS{white}
    );
    $im->string(gdSmallFont, $x1 - 8 - ($i>4?4:0), 30, "-" . (2 * $i), $COLORS{black});

  }

  $im->string(gdLargeFont, $x0 - 45, 10, "log2 (A/B)", $COLORS{black});
  $im->string(gdSmallFont, $x0 - 3, 30, "0", $COLORS{black});

  $im->string(gdLargeFont, $x0 - 300, 20, "Band", $COLORS{black});
  $im->string(gdLargeFont, $x0 + 220, 15, "Position", $COLORS{black});
  $im->string(gdLargeFont, $x0 + 220, 30, "(in 100K)", $COLORS{black});
  ##
  ## Zoom Bar
  ##
  $im->filledRectangle($x0 + 300 + 1, 15, $x0 + 300 + 35, $y1,
      $COLORS{lightblue});
  $im->string(gdLargeFont, $x0 + 300 + 1, 20, "Zoom", $COLORS{black});



  my $NUM_TICKS = 2;
  my $scaled_tick_interval = ($scaled_end - $scaled_start) / $NUM_TICKS;
  while ($scaled_tick_interval > 4 && $NUM_TICKS < 32) {
    $NUM_TICKS *= 2;
    $scaled_tick_interval /= 2;
  }
  my $scaled_tick;

  for (my $i = 0; $i <= $NUM_TICKS; $i++) {
    $scaled_tick = sprintf("%d", $scaled_start + $i * $scaled_tick_interval);
    $y1 = TranslatePixelAxis($VERT_MARGIN, sprintf("%d",
        TranslateBPAxis($scaled_start,
        $scaled_tick, $zoomscale) / $SCALED_BPS_TO_PIXEL));
    $im->filledRectangle($x0 + 300, $y1, $x0 + 300 + 3, $y1, $COLORS{black});
    $im->string(gdSmallFont, $x0 + 300 + 6, $y1 - 6, $scaled_tick,
        $COLORS{black});
    my @coords = ($x0 + 300 + 1, $y1, $x0 + 300 + 1 + 30, sprintf("%d",
        $y1+TranslateBPAxis($scaled_tick,
        $scaled_tick + $scaled_tick_interval, $zoomscale) /
        $SCALED_BPS_TO_PIXEL));
    push @{ $image_map },
        "<area shape=rect coords=\"" . join(",", @coords) ."\" " .
        "href=\"GEQuery?ORG=Hs&EFOLD=$exp_fold&ZFOLD=2&ZLEVEL=" . int($zlevel+1) .
        "&ZPOINT=$scaled_tick" .
        "&CHR=$chr&SRC=S&TISSUE=$tissue&FILTER=$filter\" " .
        "alt=\"zoom in\">";
  }

}

######################################################################
sub TranslateBPAxis {
  my ($x0_bp, $x_bp, $zoomscale) = @_;

  ## 'x' does NOT imply x-axis
  ## $x0_bp: origin, in SCALED base pair units, of the zoomed data area
  ## $x_bp:  position on genome in SCALED base pair units
  ## returns position as pixel

  return ($x_bp - $x0_bp) * $zoomscale;
}

######################################################################
sub TranslatePixelAxis {
  my ($x0_pix, $x_pix) = @_;

  ## 'x' does NOT imply x-axis
  ## $x0_pix: pixel coordinate of origin of the drawn axis
  ## $x_pix:  distance, in pixels, from origin of drawn axis

  return $x0_pix + $x_pix;

}

######################################################################
sub DiagonalHash {

  my ($im, $x0, $y0, $x1, $y1, $offset, $slope) = @_;
  my $width  = $x1 - $x0;
  my $height = $y1 - $y0;

  my $delta = abs($width - $height);
  my $smaller;
  if ($width >= $height) {
    $smaller = $height;
  } else {
    $smaller = $width;
  }
  my ($i, @c, $tmp);

  if ($width >= $height) {
    ## central rhombus
    for ($i = 0; $i <= $delta; $i += $offset) {
      @c = ($x0+$i, $y1,            $x0+$smaller+$i, $y0);
      if ($slope == -1) {$tmp = $c[0]; $c[0] = $c[2]; $c[2] = $tmp};
      $im->line(@c, $COLORS{black})
    }
    for ($i = 0; $i <= $smaller; $i += $offset) {
      ## left triangle
      @c = ($x0,    $y0+$i,         $x0+$i,          $y0);
      if ($slope == -1) {
        @c = ($x0, $y1-$i, $x0+$i, $y1);
      }
      $im->line(@c, $COLORS{black});
      ## right triangle
      @c = ($x1-$i, $y1,            $x1,             $y1-$i);
      if ($slope == -1) {
        @c = ($x1-$i, $y0, $x1, $y0+$i);
      }
      $im->line(@c, $COLORS{black})
    }
  } else {
    ## central rhombus
    for ($i = 0; $i <= $delta; $i += $offset) {
      @c = ($x0,    $y0+$smaller+$i, $x1,             $y0+$i);
      if ($slope == -1) {$tmp = $c[0]; $c[0] = $c[2]; $c[2] = $tmp};
      $im->line(@c, $COLORS{black})
    }
    for ($i = 0; $i <= $smaller; $i += $offset) {
      ## lower triangle
      @c = ($x1,    $y1-$i,         $x1-$i,          $y1);
      if ($slope == -1){
        @c = ($x0+$i, $y1, $x0, $y1-$i);
      }
      $im->line(@c, $COLORS{black});
      ## upper triangle
      @c = ($x0+$i, $y0,            $x0,             $y0+$i);
      if ($slope == -1) {
        @c = ($x1, $y0+$i, $x1-$i, $y0);
      }
      $im->line(@c, $COLORS{black})
    }
  }
}

######################################################################
sub DrawCytoBands {
  my ($im, $scaled_bp_window_start, $scaled_bp_window_end,
      $band2pos, $band2stain, $zoomscale, $image_map) = @_;

  my ($x1, $x2, $y1, $y2, $order, @coords);
  my ($name, $start, $end, $stain, $bcolor);

  $x1 = $IMAGE_WIDTH / 2 - 300;
##  $x2 = $IMAGE_WIDTH / 2 + 300;
  $x2 = $x1 + 49;

  for $order (sort numerically keys %{ $band2pos }) {
    ($name, $start, $end) = split /\t/, $$band2pos{$order};

    $stain = $$band2stain{$name};
    if (defined $COLORS{$stain}) {
      $bcolor = $COLORS{$stain};
    } elsif ($stain eq "acen") {
      $bcolor = $COLORS{white};
    } elsif ($stain eq "gvar") {
      $bcolor = $COLORS{white};
    }

    if ($start < $scaled_bp_window_start) {
      $y1 = TranslatePixelAxis($VERT_MARGIN,
          TranslateBPAxis($scaled_bp_window_start,
          $scaled_bp_window_start, $zoomscale) /
          $SCALED_BPS_TO_PIXEL);
    } else {
      $y1 = TranslatePixelAxis($VERT_MARGIN,
          TranslateBPAxis($scaled_bp_window_start, $start, $zoomscale) /
          $SCALED_BPS_TO_PIXEL);
    }

    if ($end > $scaled_bp_window_end) {
      $y2 = TranslatePixelAxis($VERT_MARGIN,
          TranslateBPAxis($scaled_bp_window_start,
          $scaled_bp_window_end  , $zoomscale) /
          $SCALED_BPS_TO_PIXEL);
    } else {
      $y2 = TranslatePixelAxis($VERT_MARGIN,
          TranslateBPAxis($scaled_bp_window_start, $end  , $zoomscale) /
          $SCALED_BPS_TO_PIXEL);
    }
    $im->filledRectangle ($x1, $y1, $x2, $y2, $bcolor);
    if (abs($y2 - $y1) > 12) {
      $im->string(gdSmallFont, $x1+2, $y1+1, $name,
          ($bcolor eq $COLORS{black} ? $COLORS{white} : $COLORS{black}));
    }
    if ($start < $scaled_bp_window_start) {
      ## don't print the band start
    } else {
      @coords = ($x1, $y1, $x2, $y2);
      push @{ $image_map },
          "<area shape=rect coords=\"" . join(",", @coords) ."\" " .
          "alt=\"$name\">";
##      $im->string(gdSmallFont, $x2-50, $y1+1, $start, $COLORS{black});
    }

    if ($stain eq "acen") {
      DiagonalHash($im, $x1, $y1, $x2, $y2, 5, 1);
      if ($name =~ /p/) {
        $im->line($x1-10, $y2, $x2+10, $y2, $COLORS{black});
      } else {
        $im->line($x1-10, $y1, $x2+10, $y1, $COLORS{black});
      }
    } elsif ($stain eq "gvar") {
      DiagonalHash($im, $x1, $y1, $x2, $y2, 5, -1);
    } elsif ($stain eq "stalk") {
      $im->line($x1, $y2, $x2, $y2, $COLORS{black});
      $im->line($x1, $y1, $x2, $y1, $COLORS{black});
      for (my $i = 0; $i < int(($y2-$y1)/5); $i++) {
          $im->line($x1+10, $y1+($i*5), $x2-10, $y1+($i*5),
          $COLORS{black});
      }
    } else {
      $im->line($x1, $y1, $x1, $y2, $COLORS{black});
      $im->line($x2, $y1, $x2, $y2, $COLORS{black});
    }

  }
}

######################################################################
sub DrawGeneBars {
  my ($im, $scaled_bp_window_start, $zoomlevel,
      $zoomscale, $org, $info, $gene_sym, $image_map) = @_;

  my ($sym);

  ## origins
  my $x0 = $IMAGE_WIDTH / 2;

  my (
      $cluster_number,
      $start,
      $end,
      $a,
      $A,
      $b,
      $B,
      $ratio_a2b,
      $log_ratio,
      $P
    );
  my ($x1, $x2, $y1, $y2);

  for (@{ $info }) {
    (
      $cluster_number,
      $start,
      $end,
      $a,
      $A,
      $b,
      $B,
      $ratio_a2b,
      $log_ratio,
      $P
    ) = split /\t/;

    if ($log_ratio < 0) {
      $x1 = TranslatePixelAxis($x0, sprintf("%d",
          $log_ratio * $GENE_BAR_CONSTANT));
      $x2 = $x0;
    } else {
      $x1 = $x0;
      $x2 = TranslatePixelAxis($x0, sprintf("%d",
          $log_ratio * $GENE_BAR_CONSTANT));
    }

    $y1 = TranslatePixelAxis(
        $VERT_MARGIN,
        TranslateBPAxis($scaled_bp_window_start, $start, $zoomscale) /
        $SCALED_BPS_TO_PIXEL);

## end - start doesn't really indicate the length of the gene
##    $y2 = TranslatePixelAxis(
##        $VERT_MARGIN,
##        TranslateBPAxis($scaled_bp_window_start, $end  , $zoomscale));

    $y2 = $y1 + $zoomlevel;   ## make it wider for higher zoom levels

    $im->filledRectangle ($x1, $y1, $x2, $y2, $COLORS{red});

    if (defined $$gene_sym{$cluster_number}) {
      $sym = $$gene_sym{$cluster_number};
    } else {
      $sym = "Hs.$cluster_number";
    }
    push @{ $image_map },
        "<area shape=rect coords=\"$x1,$y1,$x2,$y2\" " .
        "href=\"" . $BASE . "/Genes/GeneInfo?ORG=$org&" .
        "CID=$cluster_number\" " .
        "alt=\"$sym\">";
  }
}

######################################################################
sub GetCytoBandBounds {
  my ($db, $chr, $start, $end, $band2pos, $band2stain) = @_;

  my ($sql, $stm);
  my ($chromosome, $chr_start, $chr_end, $band_name, $stain);
  my ($count);
 
  $sql =
      "select chr_start, chr_end, band_name, stain " .
      "from $CGAP_SCHEMA.ucsc_cytoband " .
      "where chromosome = '$chr' " .
      "and chr_start < $end " .
      "and chr_end > $start " .
      "order by chr_start";

  $stm = $db->prepare($sql);
 
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    exit();
  }
  if(!$stm->execute()) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    exit();
  }

  $stm->bind_columns(\$chr_start, \$chr_end, \$band_name, \$stain );
  $count = 0;
  while ($stm->fetch) {
    $count++;
    $chr_start = sprintf("%d", $chr_start / $BP_SCALE);
    $chr_end   = sprintf("%d", $chr_end   / $BP_SCALE);
    $$band2pos{$count} = "$band_name\t$chr_start\t$chr_end";
    $$band2stain{$band_name} = $stain;
  } 

}

######################################################################
sub GetChrLength {
  my ($db, $chr) = @_;

  my ($sql, $stm);
  my ($chr_size);

  $sql = "select chr_size from $CGAP_SCHEMA.chromosome_info " .
      "where chromosome = '$chr' ";
 
  $stm = $db->prepare($sql);
  $stm->execute();
  $stm->bind_columns(\$chr_size);
 
  while($stm->fetch) { }
  return $chr_size;

}

######################################################################
sub GetVNTotals {
  my ($db, $org, $tissue, $data_src) = @_;

  my ($sql, $stm);
  my ($tissue_code, $histology_code, $lib_count, $seq_count);

  $sql =
      "select s.tissue_code, s.tissue_name, v.histology_code, " .
      "v.library_count, v.seq_count " .
      "from $CGAP_SCHEMA.tissue_selection s, $CGAP_SCHEMA." .
      ($org eq "Hs" ? "Hs_VN_Lib" : "Mm_VN_Lib") . " v " .
      "where v.tissue_code = s.tissue_code " .
      "and s.tissue_name = '$tissue' " .
      "and v.source = '$data_src' " .
      "and v.histology_code in (1,2)";

## Accept only histology=1 (cancer) or histology=2 (normal)
## Accept only categories with seq_count >= 2000

  $stm = $db->prepare($sql);

  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    return "";
  } else {
    if(!$stm->execute()) {
       print STDERR "$sql\n";
       print STDERR "$DBI::errstr\n";
       print STDERR "execute call failed\n";
       return "";
    }
    while(($tissue_code, $tissue, $histology_code,
        $lib_count, $seq_count) = $stm->fetchrow_array) {
      $vn_lib_count{"$tissue_code,$histology_code"} = $lib_count;
      $vn_seq_count{"$tissue_code,$histology_code"} = $seq_count;
      $code2tiss{$tissue_code} = $tissue;
      $tiss2code{$tissue} = $tissue_code;
    }
  }

}

######################################################################
sub GetGenesInWindow {
  my ($db, $org, $chr, $start, $end, $gene_start, $gene_sym) = @_;

  my ($cluster_number, $text_start, $text_end, $sym);
  my ($position);
  my ($sql, $stm);

  if ($start =~ /\d/) {
    if ($end =~ /\d/) {
      if ($start eq $end) {
        $position = "and r.chr_start = $start ";
      } else {
        $position = "and r.chr_start >= $start and r.chr_end <= $end ";
      }
    } else {
      $position = "and r.chr_start >= $start ";
    }
  } elsif ($end =~ /\d/) {
    $position = "and r.chr_end <= $end ";
  } else {
    $position = "";
  }

  $sql =
      "select r.cluster_number, r.chr_start, r.chr_end, c.gene " .
      "from $CGAP_SCHEMA.ucsc_mrna r, $CGAP_SCHEMA.hs_cluster c " .
      "where r.CHROMOSOME = '$chr' " .
      "and r.cluster_number = c.cluster_number " .
      $position .
      "order by r.chr_start, r.chr_end ";

  $stm = $db->prepare($sql);
  $stm->execute();
  $stm->bind_columns(\$cluster_number, \$text_start, \$text_end, \$sym);

  while($stm->fetch) {
    ##
    ## Save all starts; we'll display multiple starts
    ## for a single gene only if separated by 100,000 bp
    ##

#    if (not defined $$gene_start{$cluster_number}) {
      push @{ $$gene_start{$cluster_number} }, $text_start;
      if ($sym) {
        $$gene_sym{$cluster_number} = $sym;
      }
#    }
  }

}

######################################################################
sub GetGeneExpressionData {
  my ($db, $org, $chr, $start, $end, $tissue_code, $data_src, $filter,
      $exp_fold, $expr_info, $gene_sym) = @_;
 
  my ($sql, $stm);
  my ($cluster_number, $text_start, $text_end, $count);
  my ($total, $density_a, $density_b, $a, $A, $b, $B, $P, $ratio_a2b,
      $log2ratio, $laststart);
  my ($vars, %gene);
  my (%pcache);
  ##

  my (%gene_start, @gene_list, $list, $i);

  GetGenesInWindow($db, $org, $chr, $start, $end, \%gene_start,
      $gene_sym);
  @gene_list = keys %gene_start;

  for my $hist (1, 2) {
##    for ($i = 0; $i < @gene_list; $i += 1000) {
##      if(($i + 1000 - 1) < @gene_list) {
##        $list = join(",", @gene_list[$i..$i+1000-1]);
##      } else {
##        $list = join(",", @gene_list[$i..@gene_list-1]);
##      }
##      $sql =
##        "select v.cluster_number, sum(v.seq_count) " .
##        "from $CGAP_SCHEMA.hs_vn v " .
##        "where v.cluster_number in ($list) " .
##        "and v.tissue_code = $tissue_code " .
##        "and v.histology_code = $hist " .
##        "and v.source = '$data_src' " .
##        "group by v.cluster_number";

      $sql =
        "select v.cluster_number, v.seq_count " .
        "from $CGAP_SCHEMA.hs_vn v " .
        "where v.tissue_code = $tissue_code " .
        "and v.histology_code = $hist " .
        "and v.source = '$data_src' ";

      $stm = $db->prepare($sql);
      $stm->execute();
      $stm->bind_columns(\$cluster_number, \$count);
      while($stm->fetch) {
        if (not (defined $gene_start{$cluster_number})) {
          next;
        }
        if ($count == 0) { 
          next; 
        } 
        if (defined $vn_seq_count{"$tissue_code,$hist"}) {
          $total = $vn_seq_count{"$tissue_code,$hist"};
          if ($total < 1) {
            next;
          }
        } else {
          next;
        }
        if ($hist == 1) {
          $gene{$cluster_number} = join (";", $count, $total);
        } else{
          if (defined $gene{$cluster_number}) {
            ($a, $A) = split(";", $gene{$cluster_number});
            $b = $count;
            $B = $total;
            if (defined $pcache{"$a,$b"}) {
              $P = $pcache{"$a,$b"};
            } else {
              $P = sprintf "%.2f", ComputePvalue($exp_fold, $a, $b, $A, $B);
              $pcache{"$a,$b"} = $P;
            }
            if ($P > $filter) {
              next;
            }
            $density_a = sprintf "%d", ($a * $DENOM / $A);
            $density_b = sprintf "%d", ($b * $DENOM / $B);
            if ($density_a < 0.0001) {
              $density_a = 0.0001;
            }
            if ($density_b < 0.0001) {
              $density_b = 0.0001;
            }
            $ratio_a2b = sprintf("%.2f", $density_a/$density_b);
            $log2ratio = sprintf("%.2f", log2($density_a/$density_b));
            $laststart = 0;
            for (sort numerically @{ $gene_start{$cluster_number} }) {
              if ($laststart == 0 || $_ > $laststart + 100000) {
                $laststart = $_;
                $vars = join("\t", $cluster_number,
                    sprintf("%d", $_/$BP_SCALE),
                    0,
                    $a, $A, $b, $B,
                    $ratio_a2b,
                    $log2ratio,
                    $P);
                push @{ $expr_info}, $vars;
              }
	    }

          }
        }
      }
##    }
  }
      
}

######################################################################
sub Expression_1 {
  my ($base, $org, $chr, $scaled_start, $scaled_end, $tissue, $data_src,
      $filter, $exp_fold, $zoomfold, $zoomlevel, $scaled_zoompoint) = @_;

  $BASE = $base;

  my ($tissue_code);
  my (@expr_info, $scaled_chr_length);
  my (%band2pos, %band2stain);
  my ($im);
  my ($zoomscale);
  my ($image_cache_id, $imagemap_cache_id);
  my (@image_map);
  my (%gene_sym);

  my @lines;
  push @lines,
      "<image src=\"LICRImage?CACHE=$image_cache_id\" " .
      "border=0 " .
      "usemap=\"#chrmap\">";

  return
      join("\n", @lines);
  
}

######################################################################
sub GetGEFromCache_1 {
  my ($base, $cache_id) = @_;

  $BASE = $base;

  return ReadGEFromCache($cache_id);
}

######################################################################
sub ReadGEFromCache {
  my ($cache_id) = @_;

  my ($s, @data);

  if ($cache->FindCacheFile($cache_id) eq $CACHE_FAIL) {
    return "Cache expired";
  }
  my $filename = $cache->FindCacheFile($cache_id);
  open(GEIN, "$filename") or die "Can't open $filename.";
  while (read GEIN, $s, 16384) {
    push @data, $s;
  } 
  close (GEIN);
  return join("", @data);

}


######################################################################
sub WriteGEToCache {
  my ($data) = @_;

  my ($ge_cache_id, $filename) = $cache->MakeCacheFile();
  if ($ge_cache_id != $CACHE_FAIL) {
    if (open(GEOUT, ">$filename")) {
      print GEOUT $data;
      close GEOUT;
      chmod 0666, $filename;
    } else {
      $ge_cache_id = 0;
    }
  }
  return $ge_cache_id;
}

######################################################################
sub ComputePvalue {
  my ($factor, $G_A, $G_B, $total_seqsA, $total_seqsB) = @_;
  my ($P);

  if ($G_A/$total_seqsA > $G_B/$total_seqsB) {
    $P = 1 - Bayesian::Bayesian($factor,
             $G_A, $G_B, $total_seqsA, $total_seqsB);
  } else {
    $P = 1 - Bayesian::Bayesian($factor,
             $G_B, $G_A, $total_seqsB, $total_seqsA);
  }

  return $P;
}


######################################################################
1;
