#!/usr/local/bin/perl

######################################################################
# DigitalFISH.pm
#
######################################################################

use strict;
use FileHandle;
use CGAPConfig;
use Paging;
use ServerSupport;
use DBI;
use GD;
use Cache;

require LWP::UserAgent;

use constant ORACLE_LIST_LIMIT => 500;

my $BASE;
my $DEBUG_FLAG;


my $cache = new Cache(CACHE_ROOT, FISH_CACHE_PREFIX);

my $IMAGE_HEIGHT        = 2000;
my $IMAGE_WIDTH         = 800;
my $IMAGE_MARGIN        = 5;
my $VERT_MARGIN         = 50;
my $HORZ_MARGIN         = 75;
my %COLORS;

my (%top, %bottom, %left, %width, %height, %bands, %X, %Y, %YP);

######################################################################
sub numerically   { $a <=> $b; }
sub r_numerically { $b <=> $a; }


######################################################################
sub DigitalFISH_1 {

  my ($base, $org) = @_;

  my ($im, $image_cache_id, $imagemap_cache_id);
  my (@image_map);

  $im = InitializeImage();

  push @image_map, "<map name=\"fishmap\">";

  DrawGrid($im, \@image_map);

  push @image_map, "</map>";

  if (GD->require_version() > 1.19) {
    $image_cache_id = WriteFISHToCache($im->png);
  } else {
    $image_cache_id = WriteFISHToCache($im->gif);
  }

  if (! $image_cache_id) {
    return "Cache failed";
  }

  my @lines;

  push @lines,
      "<image src=\"dmhs?CACHE=$image_cache_id\" " .
      "border=0 " .
      "usemap=\"#fishmap\">";
  push @lines, @image_map;

  return
      join("\n", @lines);
}

######################################################################
sub WriteFISHToCache {
  my ($data) = @_;

  my ($fish_cache_id, $filename) = $cache->MakeCacheFile();
  if ($fish_cache_id != $CACHE_FAIL) {
    if (open(ROUT, ">$filename")) {
      print ROUT $data;
      close ROUT;
      chmod 0666, $filename;
    } else {
      $fish_cache_id = 0;
    }
  }
  return $fish_cache_id;
}

######################################################################
sub InitializeImage {

  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);

##
## allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
  $COLORS{white}       = $im->colorAllocate(255,255,255);
  $COLORS{black}       = $im->colorAllocate(0,0,0);
  $COLORS{darkblue}    = $im->colorAllocate(0,0,139);
  $COLORS{midblue}     = $im->colorAllocate(0,147,208);
  $COLORS{blue}        = $im->colorAllocate(0,0,255);

  $im->transparent($COLORS{white});
# $im->interlaced("true");

  my ($img, $chr, $width, $height, $top, $bottom, $left, $x);

  $bottom = 210;

  for ($x = 1,$left = 50 ; $x <= 6 ; $x++,$left += 100) {
    $img = "/h1/HiseD/chroms/chrom_$x.jpg";
    $chr = newFromJpeg GD::Image($img);
    ($width, $height) = $chr->getBounds();
    $top = $bottom - $height;
    $im->copy($chr,$left,$top,0,0,$width,$height);
    $im->string(gdMediumBoldFont,$left+5,$bottom,"$x",$COLORS{midblue});

    $width{$x} = $width;
    $height{$x} = $height;
    $top{$x} = $top;
    $bottom{$x} = $bottom;
    $left{$x} = $left;
  }

  $bottom += 210;

  for ($x = 7,$left = 50 ; $x <= 12 ; $x++,$left += 100) {
    $img = "/h1/HiseD/chroms/chrom_$x.jpg";
    $chr = newFromJpeg GD::Image($img);
    ($width, $height) = $chr->getBounds();
    $top = $bottom - $height;
    $im->copy($chr,$left,$top,0,0,$width,$height);
    $im->string(gdMediumBoldFont,$left+5,$bottom,"$x",$COLORS{midblue});

    $width{$x} = $width;
    $height{$x} = $height;
    $top{$x} = $top;
    $bottom{$x} = $bottom;
    $left{$x} = $left;
  }

  $bottom += 210;

  for ($x = 13,$left = 50 ; $x <= 18 ; $x++,$left += 100) {
    $img = "/h1/HiseD/chroms/chrom_$x.jpg";
    $chr = newFromJpeg GD::Image($img);
    ($width, $height) = $chr->getBounds();
    $top = $bottom - $height;
    $im->copy($chr,$left,$top,0,0,$width,$height);
    $im->string(gdMediumBoldFont,$left+5,$bottom,"$x",$COLORS{midblue});

    $width{$x} = $width;
    $height{$x} = $height;
    $top{$x} = $top;
    $bottom{$x} = $bottom;
    $left{$x} = $left;
  }

  $bottom += 210;

  for ($x = 19,$left = 50 ; $x <= 22 ; $x++,$left += 100) {
    $img = "/h1/HiseD/chroms/chrom_$x.jpg";
    $chr = newFromJpeg GD::Image($img);
    ($width, $height) = $chr->getBounds();
    $top = $bottom - $height;
    $im->copy($chr,$left,$top,0,0,$width,$height);
    $im->string(gdMediumBoldFont,$left+5,$bottom,"$x",$COLORS{midblue});

    $width{$x} = $width;
    $height{$x} = $height;
    $top{$x} = $top;
    $bottom{$x} = $bottom;
    $left{$x} = $left;
  }

  $img = "/h1/HiseD/chroms/chrom_X.jpg";
  $chr = newFromJpeg GD::Image($img);
  ($width, $height) = $chr->getBounds();
  $top = $bottom - $height;
  $im->copy($chr,$left,$top,0,0,$width,$height);
  $im->string(gdMediumBoldFont,$left+5,$bottom,"X",$COLORS{midblue});

  $width{X} = $width;
  $height{X} = $height;
  $top{X} = $top;
  $bottom{X} = $bottom;
  $left{X} = $left;

  $left += 100;

  $img = "/h1/HiseD/chroms/chrom_Y.jpg";
  $chr = newFromJpeg GD::Image($img);
  ($width, $height) = $chr->getBounds();
  $top = $bottom - $height;
  $im->copy($chr,$left,$top,0,0,$width,$height);
  $im->string(gdMediumBoldFont,$left+5,$bottom,"Y",$COLORS{midblue});

  $width{Y} = $width;
  $height{Y} = $height;
  $top{Y} = $top;
  $bottom{Y} = $bottom;
  $left{Y} = $left;

##
## allocate some more colors
##
  $COLORS{darkred}     = $im->colorAllocate(196,0,0);
  $COLORS{red}         = $im->colorAllocate(255,0,0);
  $COLORS{darksalmon}  = $im->colorAllocate(233,150,122);
  $COLORS{maroon}      = $im->colorAllocate(176,48,96);
  $COLORS{orange}      = $im->colorAllocate(245,174,29);
  $COLORS{purple}      = $im->colorAllocate(154,37,185);
  $COLORS{violet}      = $im->colorAllocate(238,130,238);
  $COLORS{orchid}      = $im->colorAllocate(184,88,153);
  $COLORS{pink}        = $im->colorAllocate(238,162,173);
  $COLORS{gold}        = $im->colorAllocate(238,216,174);
  $COLORS{teal}        = $im->colorAllocate(0,148,145);
  $COLORS{lightblue}   = $im->colorAllocate(178,238,238);
  $COLORS{midgreen}    = $im->colorAllocate(0,186,7);
  $COLORS{midyellow}   = $im->colorAllocate(251,247,157);
  $COLORS{olive}       = $im->colorAllocate(128,128,0);
  $COLORS{darkgreen}   = $im->colorAllocate(0,100,0);
  $COLORS{green}       = $im->colorAllocate(0,128,0);
  $COLORS{yellow}      = $im->colorAllocate(255,255,0);
  $COLORS{yellowgreen} = $im->colorAllocate(154,205,50);

  $COLORS{gray}        = $im->colorAllocate(128,128,128);
  $COLORS{lightgray}   = $im->colorAllocate(211,211,211);
  $COLORS{gray}        = $im->colorAllocate(200,200,200);
  $COLORS{mediumgray}  = $im->colorAllocate(220,220,220);
  $COLORS{lightgray}   = $im->colorAllocate(240,240,240);

  return $im;
}

######################################################################
sub DrawGrid {
  my ($im, $image_map) = @_;

  $im->rectangle($left{1}-2,$top{1},$left{1}-3,$bottom{1},$COLORS{darkred});
  $im->rectangle($left{1}+$width{1},$top{1},$left{1}+$width{1}+1,$bottom{1},$COLORS{darkgreen});

  $im->rectangle($left{2}-2,$top{2},$left{2}-3,$bottom{2},$COLORS{darkred});
  $im->rectangle($left{2}+$width{2},$top{2},$left{2}+$width{2}+1,$bottom{2},$COLORS{darkgreen});

  $im->rectangle($left{3}-2,$top{3},$left{3}-3,$bottom{3},$COLORS{darkred});
  $im->rectangle($left{3}+$width{3},$top{3},$left{3}+$width{3}+1,$bottom{3},$COLORS{darkgreen});

  $im->rectangle($left{4}-2,$top{4},$left{4}-3,$bottom{4},$COLORS{darkred});
  $im->rectangle($left{4}+$width{4},$top{4},$left{4}+$width{4}+1,$bottom{4},$COLORS{darkgreen});

  $im->rectangle($left{5}-2,$top{5},$left{5}-3,$bottom{5},$COLORS{darkred});
  $im->rectangle($left{5}+$width{5},$top{5},$left{5}+$width{5}+1,$bottom{5},$COLORS{darkgreen});

  $im->rectangle($left{6}-2,$top{6},$left{6}-3,$bottom{6},$COLORS{darkred});
  $im->rectangle($left{6}+$width{6},$top{6},$left{6}+$width{6}+1,$bottom{6},$COLORS{darkgreen});

  $im->rectangle($left{7}-2,$top{7},$left{7}-3,$bottom{7},$COLORS{darkred});
  $im->rectangle($left{7}+$width{7},$top{7},$left{7}+$width{7}+1,$bottom{7},$COLORS{darkgreen});

  $im->rectangle($left{8}-2,$top{8},$left{8}-3,$bottom{8},$COLORS{darkred});
  $im->rectangle($left{8}+$width{8},$top{8},$left{8}+$width{8}+1,$bottom{8},$COLORS{darkgreen});

  $im->rectangle($left{9}-2,$top{9},$left{9}-3,$bottom{9},$COLORS{darkred});
  $im->rectangle($left{9}+$width{9},$top{9},$left{9}+$width{9}+1,$bottom{9},$COLORS{darkgreen});

  $im->rectangle($left{10}-2,$top{10},$left{10}-3,$bottom{10},$COLORS{darkred});
  $im->rectangle($left{10}+$width{10},$top{10},$left{10}+$width{10}+1,$bottom{10},$COLORS{darkgreen});

  $im->rectangle($left{11}-2,$top{11},$left{11}-3,$bottom{11},$COLORS{darkred});
  $im->rectangle($left{11}+$width{11},$top{11},$left{11}+$width{11}+1,$bottom{11},$COLORS{darkgreen});

  $im->rectangle($left{12}-2,$top{12},$left{12}-3,$bottom{12},$COLORS{darkred});
  $im->rectangle($left{12}+$width{12},$top{12},$left{12}+$width{12}+1,$bottom{12},$COLORS{darkgreen});

  $im->rectangle($left{13}-2,$top{13},$left{13}-3,$bottom{13},$COLORS{darkred});
  $im->rectangle($left{13}+$width{13},$top{13},$left{13}+$width{13}+1,$bottom{13},$COLORS{darkgreen});

  $im->rectangle($left{14}-2,$top{14},$left{14}-3,$bottom{14},$COLORS{darkred});
  $im->rectangle($left{14}+$width{14},$top{14},$left{14}+$width{14}+1,$bottom{14},$COLORS{darkgreen});

  $im->rectangle($left{15}-2,$top{15},$left{15}-3,$bottom{15},$COLORS{darkred});
  $im->rectangle($left{15}+$width{15},$top{15},$left{15}+$width{15}+1,$bottom{15},$COLORS{darkgreen});

  $im->rectangle($left{16}-2,$top{16},$left{16}-3,$bottom{16},$COLORS{darkred});
  $im->rectangle($left{16}+$width{16},$top{16},$left{16}+$width{16}+1,$bottom{16},$COLORS{darkgreen});

  $im->rectangle($left{17}-2,$top{17},$left{17}-3,$bottom{17},$COLORS{darkred});
  $im->rectangle($left{17}+$width{17},$top{17},$left{17}+$width{17}+1,$bottom{17},$COLORS{darkgreen});

  $im->rectangle($left{18}-2,$top{18},$left{18}-3,$bottom{18},$COLORS{darkred});
  $im->rectangle($left{18}+$width{18},$top{18},$left{18}+$width{18}+1,$bottom{18},$COLORS{darkgreen});

  $im->rectangle($left{19}-2,$top{19},$left{19}-3,$bottom{19},$COLORS{darkred});
  $im->rectangle($left{19}+$width{19},$top{19},$left{19}+$width{19}+1,$bottom{19},$COLORS{darkgreen});

  $im->rectangle($left{20}-2,$top{20},$left{20}-3,$bottom{20},$COLORS{darkred});
  $im->rectangle($left{20}+$width{20},$top{20},$left{20}+$width{20}+1,$bottom{20},$COLORS{darkgreen});

  $im->rectangle($left{21}-2,$top{21},$left{21}-3,$bottom{21},$COLORS{darkred});
  $im->rectangle($left{21}+$width{21},$top{21},$left{21}+$width{21}+1,$bottom{21},$COLORS{darkgreen});

  $im->rectangle($left{22}-2,$top{22},$left{22}-3,$bottom{22},$COLORS{darkred});
  $im->rectangle($left{22}+$width{22},$top{22},$left{22}+$width{22}+1,$bottom{22},$COLORS{darkgreen});

  $im->rectangle($left{X}-2,$top{X},$left{X}-3,$bottom{X},$COLORS{darkred});
  $im->rectangle($left{X}+$width{X},$top{X},$left{X}+$width{X}+1,$bottom{X},$COLORS{darkgreen});

  $im->rectangle($left{Y}-2,$top{Y},$left{Y}-3,$bottom{Y},$COLORS{darkred});
  $im->rectangle($left{Y}+$width{Y},$top{Y},$left{Y}+$width{Y}+1,$bottom{Y},$COLORS{darkgreen});
}

######################################################################
sub InitializeImage3 {

  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);

##
## allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
  $COLORS{white}          = $im->colorAllocate(255,255,255);

  $COLORS{darkblue}       = $im->colorAllocate(0,0,139);
  $COLORS{midblue}        = $im->colorAllocate(0,147,208);
  $COLORS{lightblue}      = $im->colorAllocate(178,238,238);

  $COLORS{darkgreen}      = $im->colorAllocate(0,100,0);
  $COLORS{green}          = $im->colorAllocate(0,128,0);

  $COLORS{darkred}        = $im->colorAllocate(196,0,0);
  $COLORS{red}            = $im->colorAllocate(255,0,0);

  $COLORS{darksalmon}     = $im->colorAllocate(233,150,122);
  $COLORS{orange}         = $im->colorAllocate(245,174,29);

  $COLORS{purple}         = $im->colorAllocate(154,37,185);
  $COLORS{violet}         = $im->colorAllocate(238,130,238);

  $COLORS{gold}           = $im->colorAllocate(238,216,174);
  $COLORS{midyellow}      = $im->colorAllocate(251,247,157);
  $COLORS{lightyellow}    = $im->colorAllocate(238,238,209);

  $COLORS{teal}           = $im->colorAllocate(0,148,145);
  $COLORS{midturquoise}   = $im->colorAllocate(72,209,204);

  $COLORS{olive}          = $im->colorAllocate(128,128,0);

  $COLORS{pink}           = $im->colorAllocate(238,162,173);
  $COLORS{midpink}        = $im->colorAllocate(255,192,203);

  $COLORS{copper}         = $im->colorAllocate(184,115,51);

  $COLORS{darkpurple}     = $im->colorAllocate(85,26,139);

  $COLORS{goldenrod}      = $im->colorAllocate(238,173,14);

  $COLORS{cornflowerblue} = $im->colorAllocate(100,149,237);

  $COLORS{maroon}         = $im->colorAllocate(176,48,96);

  $COLORS{darksteel}      = $im->colorAllocate(54,100,139);
  $COLORS{midsteel}       = $im->colorAllocate(70,130,180);
  $COLORS{lightsteel}     = $im->colorAllocate(79,148,205);

  $COLORS{brown}          = $im->colorAllocate(139,105,105);
  $COLORS{midbrown}       = $im->colorAllocate(205,170,125);

  $COLORS{plum}           = $im->colorAllocate(139,102,139);
  $COLORS{midplum}        = $im->colorAllocate(205,150,205);

  $COLORS{mistyrose}      = $im->colorAllocate(205,183,181);

  $COLORS{darkseagreen}   = $im->colorAllocate(143,198,143);
  $COLORS{midseagreen}    = $im->colorAllocate(193,255,193);

  $COLORS{violetred}      = $im->colorAllocate(205,50,120);

  $COLORS{honeydew}       = $im->colorAllocate(131,139,131);
  $COLORS{midhoneydew}    = $im->colorAllocate(193,205,193);

  $COLORS{darkkhaki}      = $im->colorAllocate(189,183,107);
  $COLORS{midkhaki}       = $im->colorAllocate(240,230,140);

  $COLORS{magenta}        = $im->colorAllocate(205,0,205);
  $COLORS{midmagenta}     = $im->colorAllocate(255,0,255);

  $COLORS{darkslate}      = $im->colorAllocate(0,134,139);
  $COLORS{midslate}       = $im->colorAllocate(0,197,205);

  $COLORS{black}          = $im->colorAllocate(0,0,0);

  $COLORS{peru}           = $im->colorAllocate(205,133,63);
  $COLORS{midpurple}      = $im->colorAllocate(147,112,219);
  $COLORS{orchid}         = $im->colorAllocate(184,88,153);
  $COLORS{midgreen}       = $im->colorAllocate(0,186,7);
  $COLORS{yellow}         = $im->colorAllocate(255,255,0);
  $COLORS{yellowgreen}    = $im->colorAllocate(154,205,50);

  $COLORS{gray}           = $im->colorAllocate(128,128,128);
  $COLORS{lightgray}      = $im->colorAllocate(211,211,211);
  $COLORS{gray}           = $im->colorAllocate(200,200,200);
  $COLORS{mediumgray}     = $im->colorAllocate(220,220,220);
  $COLORS{lightgray}      = $im->colorAllocate(240,240,240);

  $im->transparent($COLORS{white});
# $im->interlaced("true");

  return $im;
}

######################################################################
sub DrawGrid3 {
  my ($im, $image_map) = @_;

  my ($x0, $x1, $y0, $y1, $bottom);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  my @palette = 
    ("","darkblue","darkgreen","darkred","darksalmon","purple","gold",
        "teal","olive","pink","copper","darkpurple","goldenrod",
        "cornflowerblue","maroon","darksteel","brown","plum","mistyrose",
        "darkseagreen","violetred","honeydew","darkkhaki","magenta","black");

  my @palette2 = 
    ("","midblue","midgreen","","orange","violet","midyellow",
        "midturquoise","","midpink","","","",
        "","","midsteel","midbrown","midplum","",
        "midseagreen","","midhoneydew","midkhaki","midmagenta","");

  my @palette3 = 
    ("","lightblue","","","","","lightyellow",
        "","","","","","",
        "","","lightsteel","","","",
        "","","","","","");

  my $diag = new GD::Image(200,200); 
  my $white = $diag->colorAllocate(255,255,255);
  my $black = $diag->colorAllocate(0,0,0);
  $diag->transparent($white);
# $diag->line(0,1,1,0,$black);  # ??
  $im->setBrush($diag);
# $im->setStyle($COLORS{gray},$COLORS{gray}, $COLORS{gray},$COLORS{gray},
#               $COLORS{peru},$COLORS{peru}, $COLORS{peru},$COLORS{peru});
# $im->filledRectangle(250,250,450,450,gdStyled);


# Chromosome Bands
  my %bands;
  %bands = (
    1 => {
      p => {
        15 => "$COLORS{$palette[1]},5",
        20 => "gdTransparent,6",
        26 => "$COLORS{$palette[1]},5",
        31 => "gdTransparent,4",
        35 => "$COLORS{$palette3[1]},4",
        39 => "gdTransparent,4",
        43 => "$COLORS{$palette[1]},5",
        48 => "gdTransparent,6",
        54 => "$COLORS{$palette[1]},17",
        71 => "gdTransparent,8",
        79 => "$COLORS{$palette[1]},8",
        87 => "gdTransparent,5",
        92 => "$COLORS{$palette2[1]},5"
      },
      q => {
        106 => "gdStyled,15",
        121 => "gdTransparent,8",
        129 => "$COLORS{$palette2[1]},5",
        134 => "gdTransparent,6",
        140 => "$COLORS{$palette[1]},5",
        145 => "gdTransparent,6",
        151 => "$COLORS{$palette[1]},15",
        166 => "gdTransparent,15",
        181 => "$COLORS{$palette[1]},8",
        189 => "gdTransparent,6",
        195 => "$COLORS{$palette[1]},5"
      }
    },

    2 => {
      p => {
        25 => "$COLORS{$palette[2]},6",
        31 => "gdTransparent,8",
        39 => "$COLORS{$palette[2]},7",
        46 => "gdTransparent,6",
        52 => "$COLORS{$palette[2]},10",
        62 => "gdTransparent,3",
        65 => "$COLORS{$palette2[2]},4",
        69 => "gdTransparent,8",
        77 => "$COLORS{$palette[2]},6",
        83 => "gdTransparent,7"
      },
      q => {
        93  => "$COLORS{$palette[2]},2",
        95  => "gdTransparent,5",
        100 => "$COLORS{$palette[2]},6",
        106 => "gdTransparent,5",
        111 => "$COLORS{$palette2[2]},4",
        115 => "gdTransparent,2",
        117 => "$COLORS{$palette2[2]},4",
        121 => "gdTransparent,10",
        131 => "$COLORS{$palette[2]},10",
        141 => "gdTransparent,3",
        144 => "$COLORS{$palette[2]},10",
        154 => "gdTransparent,8",
        162 => "$COLORS{$palette[2]},10",
        172 => "gdTransparent,8",
        180 => "$COLORS{$palette[2]},8",
        188 => "gdTransparent,5",
        193 => "$COLORS{$palette[2]},7"
      }
    },

    3 => {
      p => {
        55  => "$COLORS{$palette[3]},2",
        57  => "gdTransparent,5",
        62  => "$COLORS{$palette[3]},7",
        69  => "gdTransparent,3",
        72  => "$COLORS{$palette[3]},4",
        76  => "gdTransparent,18",
        94  => "$COLORS{$palette[3]},12",
        106 => "gdTransparent,5",
        111 => "$COLORS{$palette[3]},11"
      },
      q => {
        125 => "$COLORS{$palette[3]},1",
        126 => "gdStyled,5",
        131 => "gdTransparent,3",
        134 => "$COLORS{$palette[3]},6",
        140 => "gdTransparent,3",
        143 => "$COLORS{$palette[3]},8",
        151 => "gdTransparent,8",
        159 => "$COLORS{$palette[3]},4",
        163 => "gdTransparent,5",
        168 => "$COLORS{$palette[3]},8",
        176 => "gdTransparent,4",
        180 => "$COLORS{$palette[3]},6",
        186 => "gdTransparent,3",
        189 => "$COLORS{$palette[3]},5",
        194 => "gdTransparent,5",
        199 => "$COLORS{$palette[3]},3"
      }
    },

    4 => {
      p => {
        70  => "gdTransparent,4",
        74  => "$COLORS{$palette[4]},4",
        78  => "gdTransparent,3",
        81  => "$COLORS{$palette[4]},5",
        86  => "gdTransparent,7",
        93  => "$COLORS{$palette2[4]},3",
        96  => "gdTransparent,3",
        99  => "$COLORS{$palette[4]},1"
      },
      q => {
        104 => "$COLORS{$palette[4]},2",
        105 => "gdTransparent,7",
        112 => "$COLORS{$palette[4]},10",
        122 => "gdTransparent,12",
        134 => "$COLORS{$palette[4]},7",
        141 => "gdTransparent,1",
        142 => "$COLORS{$palette2[4]},6",
        148 => "gdTransparent,3",
        151 => "$COLORS{$palette[4]},7",
        158 => "gdTransparent,3",
        161 => "$COLORS{$palette[4]},12",
        173 => "gdTransparent,4",
        177 => "$COLORS{$palette[4]},3",
        180 => "gdTransparent,5",
        185 => "$COLORS{$palette[4]},6",
        191 => "gdTransparent,4",
        195 => "$COLORS{$palette[4]},5"
      }
    },

    5 => {
      p => {
        80  => "$COLORS{$palette2[5]},3",
        83  => "gdTransparent,4",
        87  => "$COLORS{$palette[5]},10",
        97  => "gdTransparent,5",
        102 => "$COLORS{$palette[5]},3"
      },
      q => {
        109 => "$COLORS{$palette[5]},2",
        111 => "gdTransparent,6",
        117 => "$COLORS{$palette[5]},5",
        122 => "gdTransparent,10",
        132 => "$COLORS{$palette[5]},10",
        142 => "gdTransparent,4",
        146 => "$COLORS{$palette[5]},10",
        156 => "gdTransparent,4",
        160 => "$COLORS{$palette[5]},10",
        170 => "gdTransparent,12",
        182 => "$COLORS{$palette[5]},6",
        188 => "gdTransparent,5",
        193 => "$COLORS{$palette[5]},7"
      }
    },

    6 => {
      p => {
        85  => "$COLORS{$palette[6]},3",
        88  => "gdTransparent,5",
        93  => "$COLORS{$palette[6]},8",
        101 => "gdTransparent,7",
        108 => "$COLORS{$palette3[6]},2",
        110 => "gdTransparent,6",
        116 => "$COLORS{$palette[6]},8",
        124 => "gdTransparent,1",
      },
      q => {
        129 => "$COLORS{$palette[6]},8",
        137 => "gdTransparent,3",
        140 => "$COLORS{$palette[6]},6",
        146 => "gdTransparent,4",
        150 => "$COLORS{$palette[6]},7",
        157 => "gdTransparent,8",
        165 => "$COLORS{$palette[6]},12",
        177 => "gdTransparent,6",
        183 => "$COLORS{$palette[6]},7",
        190 => "gdTransparent,7",
        197 => "$COLORS{$palette2[6]},3"
      }
    },

    7 => {
      p => {
        310 => "$COLORS{$palette[7]},10",
        320 => "gdTransparent,7",
        327 => "$COLORS{$palette[7]},6",
        333 => "gdTransparent,5",
        338 => "$COLORS{$palette[7]},4",
        342 => "gdTransparent,3"
      },
      q => {
        349 => "$COLORS{$palette[7]},1",
        350 => "gdTransparent,14",
        364 => "$COLORS{$palette[7]},12",
        376 => "gdTransparent,10",
        386 => "$COLORS{$palette[7]},12",
        398 => "gdTransparent,6",
        404 => "$COLORS{$palette2[7]},4",
        408 => "gdTransparent,4",
        412 => "$COLORS{$palette[7]},3"
      }
    },

    8 => {
      p => {
        320 => "$COLORS{$palette[8]},6",
        326 => "gdTransparent,6",
        332 => "$COLORS{$palette[8]},7",
        339 => "gdTransparent,6"
      },
      q => {
        349 => "$COLORS{$palette[8]},2",
        351 => "gdTransparent,4",
        355 => "$COLORS{$palette[8]},6",
        361 => "gdTransparent,6",
        367 => "$COLORS{$palette[8]},7",
        374 => "gdTransparent,3",
        377 => "$COLORS{$palette[8]},7",
        384 => "gdTransparent,9",
        393 => "$COLORS{$palette[8]},9",
        402 => "gdTransparent,9",
        411 => "$COLORS{$palette[8]},4"
      }
    },

    9 => {
      p => {
        320 => "$COLORS{$palette[9]},6",
        326 => "gdTransparent,2",
        328 => "$COLORS{$palette[9]},7",
        335 => "gdTransparent,7",
        342 => "$COLORS{$palette2[9]},3"
      },
      q => {
        349 => "$COLORS{$palette[9]},1",
        350 => "gdStyled,14",
        364 => "gdTransparent,4",
        368 => "$COLORS{$palette[9]},15",
        382 => "gdTransparent,14",
        396 => "$COLORS{$palette[9]},8",
        404 => "gdTransparent,2",
        406 => "$COLORS{$palette[9]},5",
        411 => "gdTransparent,4"
      }
    },

    10 => {
      p => {
        320 => "$COLORS{$palette[10]},4",
        324 => "gdTransparent,5",
        329 => "$COLORS{$palette[10]},10",
        339 => "gdTransparent,6"
      },
      q => {
        349 => "$COLORS{$palette[10]},1",
        350 => "gdTransparent,7",
        357 => "$COLORS{$palette[10]},18",
        375 => "gdTransparent,12",
        387 => "$COLORS{$palette[10]},10",
        397 => "gdTransparent,10",
        407 => "$COLORS{$palette[10]},8"
      }
    },

    11 => {
      p => {
        328 => "$COLORS{$palette[11]},10",
        338 => "gdTransparent,4",
        342 => "$COLORS{$palette[11]},6",
        347 => "gdTransparent,8"
      },
      q => {
        359 => "$COLORS{$palette[11]},10",
        369 => "gdTransparent,12",
        381 => "$COLORS{$palette[11]},10",
        391 => "gdTransparent,3",
        394 => "$COLORS{$palette[11]},8",
        402 => "gdTransparent,11",
        413 => "$COLORS{$palette[11]},4"
      }
    },

    12 => {
      p => {
        332 => "$COLORS{$palette[12]},10",
        342 => "gdTransparent,8"
      },
      q => {
        354 => "$COLORS{$palette[12]},8",
        362 => "gdTransparent,10",
        372 => "$COLORS{$palette[12]},7",
        379 => "gdTransparent,4",
        383 => "$COLORS{$palette[12]},12",
        395 => "gdTransparent,7",
        402 => "$COLORS{$palette[12]},6",
        408 => "gdTransparent,7",
        415 => "$COLORS{$palette[12]},2"
      }
    },

    13 => {
      p => {
        541 => "$COLORS{$palette[13]},1",
      },
      q => {
        554 => "$COLORS{$palette[13]},2",
        556 => "gdTransparent,8",
        564 => "$COLORS{$palette[13]},5",
        569 => "gdTransparent,8",
        577 => "$COLORS{$palette[13]},14",
        591 => "gdTransparent,6",
        597 => "$COLORS{$palette[13]},8",
        605 => "gdTransparent,7",
        612 => "$COLORS{$palette[13]},4"
      }
    },

    14 => {
      p => {
        543 => "$COLORS{$palette[14]},1",
      },
      q => {
        556 => "$COLORS{$palette[14]},2",
        558 => "gdTransparent,6",
        564 => "$COLORS{$palette[14]},6",
        570 => "gdTransparent,5",
        575 => "$COLORS{$palette[14]},11",
        586 => "gdTransparent,6",
        592 => "$COLORS{$palette[14]},3",
        595 => "gdTransparent,14",
        609 => "$COLORS{$palette[14]},6"
      }
    },

    15 => {
      p => {
        540 => "$COLORS{$palette[15]},1",
      },
      q => {
        559 => "gdTransparent,2",
        561 => "$COLORS{$palette2[15]},2",
        563 => "gdTransparent,2",
        565 => "$COLORS{$palette[15]},5",
        571 => "gdTransparent,7",
        578 => "$COLORS{$palette[15]},12",
        590 => "gdTransparent,8",
        598 => "$COLORS{$palette3[15]},4",
        602 => "gdTransparent,8",
        610 => "$COLORS{$palette[15]},5"
      }
    },

    16 => {
      p => {
        559 => "$COLORS{$palette2[16]},3",
        562 => "gdTransparent,5",
        567 => "$COLORS{$palette[16]},6",
        573 => "gdTransparent,7"
      },
      q => {
        584 => "$COLORS{$palette[16]},1",
        585 => "gdStyled,10",
        595 => "$COLORS{$palette2[16]},1",
        596 => "gdTransparent,4",
        600 => "$COLORS{$palette[16]},5",
        605 => "gdTransparent,6",
        611 => "$COLORS{$palette[16]},5"
      }
    },

    17 => {
      p => {
        563 => "$COLORS{$palette[17]},6",
        569 => "gdTransparent,7"
      },
      q => {
        579 => "$COLORS{$palette[17]},1",
        580 => "gdTransparent,3",
        583 => "$COLORS{$palette2[17]},5",
        588 => "gdTransparent,11",
        599 => "$COLORS{$palette[17]},7",
        606 => "gdTransparent,3",
        609 => "$COLORS{$palette[17]},7"
      }
    },

    18 => {
      p => {
        566 => "gdTransparent,9"
      },
      q => {
        579 => "gdTransparent,8",
        587 => "$COLORS{$palette[18]},10",
        597 => "gdTransparent,12",
        609 => "$COLORS{$palette[18]},6"
      }
    },

    19 => {
      p => {
        775 => "$COLORS{$palette2[19]},6",
        781 => "gdTransparent,6",
        787 => "gdStyled,3"
      },
      q => {
        794 => "gdStyled,3",
        797 => "gdTransparent,8",
        805 => "$COLORS{$palette[19]},5",
        810 => "gdTransparent,5"
      }
    },

    20 => {
      p => {
        775 => "$COLORS{$palette[20]},7",
        782 => "gdTransparent,8"
      },
      q => {
        794 => "$COLORS{$palette[20]},1",
        795 => "gdTransparent,5",
        800 => "$COLORS{$palette[20]},4",
        804 => "gdTransparent,5",
        809 => "$COLORS{$palette[20]},5"
      }
    },

    21 => {
      p => {
        784 => "$COLORS{$palette[21]},1"
      },
      q => {
        795 => "$COLORS{$palette[21]},2",
        797 => "gdTransparent,3",
        800 => "$COLORS{$palette[21]},9"
      }
    },

    22 => {
      p => {
        779 => "$COLORS{$palette[22]},1",
        782 => "$COLORS{$palette[22]},1"
      },
      q => {
        794 => "$COLORS{$palette[22]},1",
        795 => "gdTransparent,7",
        802 => "$COLORS{$palette[22]},6"
      }
    },

    X => {
      p => {
        710 => "$COLORS{$palette[23]},3",
        713 => "gdTransparent,7",
        720 => "$COLORS{$palette[23]},12",
        732 => "gdTransparent,3",
        735 => "$COLORS{$palette[23]},3",
        738 => "gdTransparent,7"
      },
      q => {
        749 => "$COLORS{$palette[23]},2",
        751 => "$COLORS{$palette2[23]},3",
        754 => "gdTransparent,9",
        763 => "$COLORS{$palette[23]},15",
        778 => "gdTransparent,5",
        783 => "$COLORS{$palette[23]},6",
        789 => "gdTransparent,5",
        794 => "$COLORS{$palette[23]},7",
        801 => "gdTransparent,6",
        807 => "$COLORS{$palette[23]},7"
      }
    },

    Y => {
      p => {
        774 => "$COLORS{$palette[24]},2",
        776 => "gdTransparent,6"
      },
      q => {
        785 => "$COLORS{$palette[24]},1",
        786 => "gdTransparent,16",
        802 => "gdStyled,15"
      }
    }
  );

  $bottom = 220;

  ## Chromosome 1
  $chromColor = $COLORS{$palette[1]};
  $x0 = 141;
  $x1 = 159;
  $im->filledArc(150,106,20,20,180,360,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr (1) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = 15;
  $y1 = 97;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 106;
  $y1 = 200;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # middle
  $y0 = 97;
  $y1 = 98;
  $x0 = 145;
  $x1 = 155;

  $im->filledRectangle (
      $x0,
      $y0,
      $x1,
      $y1,
      $chromColor
  );

  $im->arc(150,15,20,16,180,360,$chromColor);
  $im->arc(150,200,20,14,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"1",$chromColor);

  ## Chromosome 2
  $chromColor = $COLORS{$palette[2]};
  $x0 = 241;
  $x1 = 259;

  for $chr (2) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 25;
  $y1 = 90;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 93;
  $y1 = 200;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # middle
  $y0 = 90;
  $y1 = 93;
  $x0 = 244;
  $x1 = 256;

  $im->filledRectangle (
      $x0,
      $y0,
      $x1,
      $y1,
      $chromColor
  );

  $im->arc(250,25,20,17,180,360,$chromColor);
  $im->arc(250,200,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"2",$chromColor);

  ## Chromosome 3
  $chromColor = $COLORS{$palette[3]};
  $x0 = 341;
  $x1 = 359;
  $im->filledArc(350,119,15,15,20,160,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr (3) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = 55;
  $y1 = 122;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 125;
  $y1 = 200;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->filledRectangle(346,53,354,54,$chromColor);
  $im->arc(350,200,20,15,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"3",$chromColor);

  ## Chromosome 4
  $chromColor = $COLORS{$palette[4]};
  $x0 = 441;
  $x1 = 459;
  $im->filledArc(450,99,15,15,20,160,$chromColor);

  for $chr (4) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 70;
  $y1 = 100;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 104;
  $y1 = 200;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(450,70,20,20,180,360,$chromColor);
  $im->arc(450,200,20,16,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"4",$chromColor);

  ## Chromosome 5
  $chromColor = $COLORS{$palette[5]};
  $x0 = 541;
  $x1 = 559;
  $im->filledArc(550,104,15,15,20,160,$chromColor);

  for $chr (5) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }

     # top
  $y0 = 80;
  $y1 = 105;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 109;
  $y1 = 200;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(550,80,20,18,180,360,$chromColor);
  $im->arc(550,200,20,17,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"5",$chromColor);

  ## Chromosome 6
  $chromColor = $COLORS{$palette[6]};
  $x0 = 641;
  $x1 = 659;
  $im->filledArc(650,124,15,15,20,160,$chromColor);

  for $chr (6) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 85;
  $y1 = 125;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 129;
  $y1 = 200;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(650,85,20,18,180,360,$chromColor);
  $im->arc(650,200,20,18,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"6",$chromColor);


  $bottom = 440;

  ## Chromosome 7
  $chromColor = $COLORS{$palette[7]};
  $x0 = 141;
  $x1 = 159;
  $im->filledArc(150,344,15,15,20,160,$chromColor);

  for $chr (7) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 310;
  $y1 = 345;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 349;
  $y1 = 415;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(150,310,20,17,180,360,$chromColor);
  $im->arc(150,415,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"7",$chromColor);

  ## Chromosome 8
  $chromColor = $COLORS{$palette[8]};
  $x0 = 241;
  $x1 = 259;
  $im->filledArc(250,344,15,15,20,160,$chromColor);

  for $chr (8) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 320;
  $y1 = 345;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 349;
  $y1 = 415;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(250,320,20,20,180,360,$chromColor);
  $im->arc(250,415,20,14,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"8",$chromColor);

  ## Chromosome 9
  $chromColor = $COLORS{$palette[9]};
  $x0 = 341;
  $x1 = 359;
  $im->filledArc(350,344,15,15,20,160,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr (9) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = 320;
  $y1 = 345;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 349;
  $y1 = 415;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(350,320,20,15,180,360,$chromColor);
  $im->arc(350,415,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"9",$chromColor);

  ## Chromosome 10
  $chromColor = $COLORS{$palette[10]};
  $x0 = 441;
  $x1 = 459;
  $im->filledArc(450,344,15,15,20,160,$chromColor);

  for $chr (10) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 320;
  $y1 = 345;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 349;
  $y1 = 415;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(450,320,20,17,180,360,$chromColor);
  $im->arc(450,415,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"10",$chromColor);

  ## Chromosome 11
  $chromColor = $COLORS{$palette[11]};
  $x0 = 541;
  $x1 = 559;
  $im->filledArc(550,354,15,15,20,160,$chromColor);

  for $chr (11) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 320;
  $y1 = 355;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 359;
  $y1 = 415;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(550,320,20,20,180,360,$chromColor);
  $im->arc(550,415,20,15,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"11",$chromColor);

  ## Chromosome 12
  $chromColor = $COLORS{$palette[12]};
  $x0 = 641;
  $x1 = 659;
  $im->filledArc(650,349,15,15,20,160,$chromColor);

  for $chr (12) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 330;
  $y1 = 350;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 354;
  $y1 = 415;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(650,330,20,20,180,360,$chromColor);
  $im->arc(650,415,20,18,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"12",$chromColor);


  $bottom = 640;

  ## Chromosome 13
  $chromColor = $COLORS{$palette[13]};
  $x0 = 141;
  $x1 = 159;
  $im->filledArc(150,549,15,15,0,180,$chromColor);

  for $chr (13) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }

     # bottom
  $y0 = 554;
  $y1 = 615;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->setStyle($COLORS{mediumgray},$COLORS{mediumgray},
                $COLORS{mediumgray},$COLORS{mediumgray},
                $chromColor, $chromColor,
                $chromColor, $chromColor);

  $poly = new GD::Polygon;
  $poly->addPt(141,550);
  $poly->addPt(141,549);
  $poly->addPt(142,548);
  $poly->addPt(143,546);
  $poly->addPt(145,545);
  $poly->addPt(155,545);
  $poly->addPt(157,546);
  $poly->addPt(158,548);
  $poly->addPt(159,549);
  $poly->addPt(159,550);
  $im->filledPolygon($poly,gdStyled);

  $im->arc(150,615,20,16,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"13",$chromColor);

  $poly = new GD::Polygon;
  $poly->addPt(143,534);
  $poly->addPt(157,534);
  $poly->addPt(159,536);
  $poly->addPt(157,538);
  $poly->addPt(143,538);
  $poly->addPt(141,536);
  $im->filledPolygon($poly,gdStyled);

  ## Chromosome 14
  $chromColor = $COLORS{$palette[14]};
  $x0 = 241;
  $x1 = 259;
  $im->filledArc(250,551,18,12,0,180,$chromColor);

  for $chr (14) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }

     # bottom
  $y0 = 556;
  $y1 = 615;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->setStyle($COLORS{mediumgray},$COLORS{mediumgray},
                $COLORS{mediumgray},$COLORS{mediumgray},
                $chromColor, $chromColor,
                $chromColor, $chromColor);

  $poly = new GD::Polygon;
  $poly->addPt(241,552);
  $poly->addPt(241,551);
  $poly->addPt(242,550);
  $poly->addPt(243,548);
  $poly->addPt(245,547);
  $poly->addPt(255,547);
  $poly->addPt(257,548);
  $poly->addPt(258,550);
  $poly->addPt(259,551);
  $poly->addPt(259,552);
  $im->filledPolygon($poly,gdStyled);

  $im->arc(250,615,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"14",$chromColor);

  $poly = new GD::Polygon;
  $poly->addPt(243,536);
  $poly->addPt(257,536);
  $poly->addPt(259,538);
  $poly->addPt(257,540);
  $poly->addPt(243,540);
  $poly->addPt(241,538);
  $im->filledPolygon($poly,gdStyled);

  ## Chromosome 15
  $chromColor = $COLORS{$palette[15]};
  $x0 = 341;
  $x1 = 359;
  $im->filledArc(350,550,18,10,0,180,$chromColor);
  $im->filledArc(350,559,18,10,180,360,$chromColor);

  for $chr (15) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }

     # bottom
  $y0 = 559;
  $y1 = 615;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->setStyle($COLORS{mediumgray},$COLORS{mediumgray},
                $COLORS{mediumgray},$COLORS{mediumgray},
                $chromColor, $chromColor,
                $chromColor, $chromColor);

  $poly = new GD::Polygon;
  $poly->addPt(341,550);
  $poly->addPt(341,549);
  $poly->addPt(342,548);
  $poly->addPt(343,546);
  $poly->addPt(345,545);
  $poly->addPt(355,545);
  $poly->addPt(357,546);
  $poly->addPt(358,548);
  $poly->addPt(359,549);
  $poly->addPt(359,550);
  $im->filledPolygon($poly,gdStyled);

  $im->arc(350,615,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"15",$chromColor);

  $poly = new GD::Polygon;
  $poly->addPt(343,533);
  $poly->addPt(357,533);
  $poly->addPt(359,535);
  $poly->addPt(357,537);
  $poly->addPt(343,537);
  $poly->addPt(341,535);
  $im->filledPolygon($poly,gdStyled);

  ## Chromosome 16
  $chromColor = $COLORS{$palette[16]};
  $x0 = 441;
  $x1 = 459;
  $im->filledArc(450,579,15,15,20,160,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr (16) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = 560;
  $y1 = 580;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 584;
  $y1 = 615;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(450,560,20,17,180,360,$chromColor);
  $im->arc(450,615,20,17,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"16",$chromColor);

  ## Chromosome 17
  $chromColor = $COLORS{$palette[17]};
  $x0 = 541;
  $x1 = 559;
  $im->filledArc(550,574,15,15,20,160,$chromColor);

  for $chr (17) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 563;
  $y1 = 576;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 579;
  $y1 = 615;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(550,563,20,20,180,360,$chromColor);
  $im->arc(550,615,20,16,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"17",$chromColor);

  ## Chromosome 18
  $chromColor = $COLORS{$palette[18]};
  $x0 = 641;
  $x1 = 659;
  $im->filledArc(650,574,15,15,20,160,$chromColor);

  for $chr (18) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 565;
  $y1 = 575;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 579;
  $y1 = 615;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->filledArc(650,565,20,20,180,360,$chromColor);
  $im->arc(650,615,20,16,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"18",$chromColor);

  $bottom = 840;

  ## Chromosome 19
  $chromColor = $COLORS{$palette[19]};
  $x0 = 141;
  $x1 = 159;
  $im->filledArc(150,789,15,15,20,160,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr (19) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = 775;
  $y1 = 790;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 794;
  $y1 = 815;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(150,775,20,20,180,360,$chromColor);
  $im->filledArc(150,815,20,15,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"19",$chromColor);

  ## Chromosome 20
  $chromColor = $COLORS{$palette[20]};
  $x0 = 241;
  $x1 = 259;
  $im->filledArc(250,789,15,15,20,160,$chromColor);

  for $chr (20) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 775;
  $y1 = 790;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 794;
  $y1 = 815;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(250,775,20,18,180,360,$chromColor);
  $im->arc(250,815,20,14,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"20",$chromColor);

  ## Chromosome 21
  $chromColor = $COLORS{$palette[21]};
  $x0 = 341;
  $x1 = 359;
  $im->filledArc(350,789,15,15,20,160,$chromColor);

  for $chr (21) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 784;
  $y1 = 785;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 795;
  $y1 = 813;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->setStyle($COLORS{$palette2[21]},$COLORS{$palette2[21]},
                $COLORS{$palette2[21]},$COLORS{$palette2[21]},
                $chromColor, $chromColor,
                $chromColor, $chromColor);

  $poly = new GD::Polygon;
  $poly->addPt(341,792);
  $poly->addPt(341,791);
  $poly->addPt(342,790);
  $poly->addPt(343,788);
  $poly->addPt(345,787);
  $poly->addPt(355,787);
  $poly->addPt(357,788);
  $poly->addPt(358,790);
  $poly->addPt(359,791);
  $poly->addPt(359,792);
  $im->filledPolygon($poly,gdStyled);

  $im->arc(350,815,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"21",$chromColor);

  $poly = new GD::Polygon;
  $poly->addPt(343,778);
  $poly->addPt(357,778);
  $poly->addPt(359,780);
  $poly->addPt(357,782);
  $poly->addPt(343,782);
  $poly->addPt(341,780);
  $im->filledPolygon($poly,gdStyled);

  ## Chromosome 22
  $chromColor = $COLORS{$palette[22]};
  $x0 = 441;
  $x1 = 459;
  $im->filledArc(450,789,15,15,20,160,$chromColor);

  for $chr (22) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 779;
  $y1 = 780;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $y0 = 782;
  $y1 = 783;
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 794;
  $y1 = 813;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->setStyle($COLORS{$palette2[22]},$COLORS{$palette2[22]},
                $COLORS{$palette2[22]},$COLORS{$palette2[22]},
                $chromColor, $chromColor,
                $chromColor, $chromColor);

  $poly = new GD::Polygon;
  $poly->addPt(441,790);
  $poly->addPt(441,789);
  $poly->addPt(442,788);
  $poly->addPt(443,787);
  $poly->addPt(444,786);
  $poly->addPt(445,786);
  $poly->addPt(446,785);
  $poly->addPt(447,785);
  $poly->addPt(448,784);
  $poly->addPt(449,784);
  $poly->addPt(450,784);
  $poly->addPt(451,784);
  $poly->addPt(452,784);
  $poly->addPt(453,785);
  $poly->addPt(454,785);
  $poly->addPt(455,786);
  $poly->addPt(456,786);
  $poly->addPt(457,787);
  $poly->addPt(458,788);
  $poly->addPt(459,789);
  $poly->addPt(459,790);
  $im->filledPolygon($poly,gdStyled);

  $im->arc(450,815,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"22",$chromColor);

  $poly = new GD::Polygon;
  $poly->addPt(443,773);
  $poly->addPt(457,773);
  $poly->addPt(459,775);
  $poly->addPt(457,777);
  $poly->addPt(443,777);
  $poly->addPt(441,775);
  $im->filledPolygon($poly,gdStyled);

  ## Chromosome X
  $chromColor = $COLORS{$palette[23]};
  $x0 = 541;
  $x1 = 559;
  $im->filledRectangle(545,747,555,748,$chromColor);

  for $chr ('X') {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = 710;
  $y1 = 745;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 749;
  $y1 = 813;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc(550,710,20,14,180,360,$chromColor);
  $im->arc(550,813,20,14,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"X",$chromColor);

  ## Chromosome Y
  $chromColor = $COLORS{$palette[24]};
  $x0 = 641;
  $x1 = 659;
  $im->filledArc(650,779,15,15,20,160,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr ('Y') {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = 774;
  $y1 = 782;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = 785;
  $y1 = 815;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->filledRectangle(645,771,655,772,$chromColor);
  $im->arc(650,815,20,20,0,180,$chromColor);
  $poly = new GD::Polygon;
  $poly->addPt(641,818);
  $poly->addPt(641,819);
  $poly->addPt(642,819);
  $poly->addPt(643,820);
  $poly->addPt(644,821);
  $poly->addPt(645,821);
  $poly->addPt(646,822);
  $poly->addPt(647,822);
  $poly->addPt(648,823);
  $poly->addPt(649,823);
  $poly->addPt(650,823);
  $poly->addPt(651,823);
  $poly->addPt(652,823);
  $poly->addPt(653,822);
  $poly->addPt(654,822);
  $poly->addPt(655,821);
  $poly->addPt(656,821);
  $poly->addPt(657,820);
  $poly->addPt(658,819);
  $poly->addPt(659,819);
  $poly->addPt(659,818);
  $im->filledPolygon($poly,gdStyled);

  $im->string(gdMediumBoldFont,$x0+5,$bottom,"Y",$chromColor);

}

######################################################################
# Chromosome Palettes
  my @palette = 
    ("","darkblue","darkgreen","darkred","darksalmon","purple","gold",
        "teal","olive","pink","copper","darkpurple","goldenrod",
        "cornflowerblue","maroon","darksteel","brown","plum","mistyrose",
        "darkseagreen","violetred","honeydew","darkkhaki","magenta","black");

  my @palette2 = 
    ("","midblue","midgreen","","orange","violet","midyellow",
        "midturquoise","","midpink","","","",
        "","","midsteel","midbrown","midplum","",
        "midseagreen","","midhoneydew","midkhaki","midmagenta","");

  my @palette3 = 
    ("","lightblue","","","","","lightyellow",
        "","","","","","",
        "","","lightsteel","","","",
        "","","","","","");

######################################################################
sub InitializeImage4 {

  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);

##
## allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
  $COLORS{white}          = $im->colorAllocate(255,255,255);

  $COLORS{darkblue}       = $im->colorAllocate(0,0,139);
  $COLORS{midblue}        = $im->colorAllocate(0,147,208);
  $COLORS{lightblue}      = $im->colorAllocate(178,238,238);

  $COLORS{darkgreen}      = $im->colorAllocate(0,100,0);
  $COLORS{green}          = $im->colorAllocate(0,128,0);

  $COLORS{darkred}        = $im->colorAllocate(196,0,0);
  $COLORS{red}            = $im->colorAllocate(255,0,0);

  $COLORS{darksalmon}     = $im->colorAllocate(233,150,122);
  $COLORS{orange}         = $im->colorAllocate(245,174,29);

  $COLORS{purple}         = $im->colorAllocate(154,37,185);
  $COLORS{violet}         = $im->colorAllocate(238,130,238);

  $COLORS{gold}           = $im->colorAllocate(238,216,174);
  $COLORS{midyellow}      = $im->colorAllocate(251,247,157);
  $COLORS{lightyellow}    = $im->colorAllocate(238,238,209);

  $COLORS{teal}           = $im->colorAllocate(0,148,145);
  $COLORS{midturquoise}   = $im->colorAllocate(72,209,204);

  $COLORS{olive}          = $im->colorAllocate(128,128,0);

  $COLORS{pink}           = $im->colorAllocate(238,162,173);
  $COLORS{midpink}        = $im->colorAllocate(255,192,203);

  $COLORS{copper}         = $im->colorAllocate(184,115,51);

  $COLORS{darkpurple}     = $im->colorAllocate(85,26,139);

  $COLORS{goldenrod}      = $im->colorAllocate(238,173,14);

  $COLORS{cornflowerblue} = $im->colorAllocate(100,149,237);

  $COLORS{maroon}         = $im->colorAllocate(176,48,96);

  $COLORS{darksteel}      = $im->colorAllocate(54,100,139);
  $COLORS{midsteel}       = $im->colorAllocate(70,130,180);
  $COLORS{lightsteel}     = $im->colorAllocate(79,148,205);

  $COLORS{brown}          = $im->colorAllocate(139,105,105);
  $COLORS{midbrown}       = $im->colorAllocate(205,170,125);

  $COLORS{plum}           = $im->colorAllocate(139,102,139);
  $COLORS{midplum}        = $im->colorAllocate(205,150,205);

  $COLORS{mistyrose}      = $im->colorAllocate(205,183,181);

  $COLORS{darkseagreen}   = $im->colorAllocate(143,198,143);
  $COLORS{midseagreen}    = $im->colorAllocate(193,255,193);

  $COLORS{violetred}      = $im->colorAllocate(205,50,120);

  $COLORS{honeydew}       = $im->colorAllocate(131,139,131);
  $COLORS{midhoneydew}    = $im->colorAllocate(193,205,193);

  $COLORS{darkkhaki}      = $im->colorAllocate(189,183,107);
  $COLORS{midkhaki}       = $im->colorAllocate(240,230,140);

  $COLORS{magenta}        = $im->colorAllocate(205,0,205);
  $COLORS{midmagenta}     = $im->colorAllocate(255,0,255);

  $COLORS{darkslate}      = $im->colorAllocate(0,134,139);
  $COLORS{midslate}       = $im->colorAllocate(0,197,205);

  $COLORS{black}          = $im->colorAllocate(0,0,0);

  $COLORS{peru}           = $im->colorAllocate(205,133,63);
  $COLORS{midpurple}      = $im->colorAllocate(147,112,219);
  $COLORS{orchid}         = $im->colorAllocate(184,88,153);
  $COLORS{midgreen}       = $im->colorAllocate(0,186,7);
  $COLORS{yellow}         = $im->colorAllocate(255,255,0);
  $COLORS{yellowgreen}    = $im->colorAllocate(154,205,50);

  $COLORS{gray}           = $im->colorAllocate(128,128,128);
  $COLORS{lightgray}      = $im->colorAllocate(211,211,211);
  $COLORS{gray}           = $im->colorAllocate(200,200,200);
  $COLORS{mediumgray}     = $im->colorAllocate(220,220,220);
  $COLORS{lightgray}      = $im->colorAllocate(240,240,240);

  $im->transparent($COLORS{white});
# $im->interlaced("true");

# Chromosome Bands
  %bands = (
    1 => {
      p => {
        15 => "$COLORS{$palette[1]},5",
        20 => "gdTransparent,6",
        26 => "$COLORS{$palette[1]},5",
        31 => "gdTransparent,4",
        35 => "$COLORS{$palette3[1]},4",
        39 => "gdTransparent,4",
        43 => "$COLORS{$palette[1]},5",
        48 => "gdTransparent,6",
        54 => "$COLORS{$palette[1]},17",
        71 => "gdTransparent,8",
        79 => "$COLORS{$palette[1]},8",
        87 => "gdTransparent,5",
        92 => "$COLORS{$palette2[1]},5"
      },
      q => {
        106 => "gdStyled,15",
        121 => "gdTransparent,8",
        129 => "$COLORS{$palette2[1]},5",
        134 => "gdTransparent,6",
        140 => "$COLORS{$palette[1]},5",
        145 => "gdTransparent,6",
        151 => "$COLORS{$palette[1]},15",
        166 => "gdTransparent,15",
        181 => "$COLORS{$palette[1]},8",
        189 => "gdTransparent,6",
        195 => "$COLORS{$palette[1]},5"
      }
    },

    2 => {
      p => {
        25 => "$COLORS{$palette[2]},6",
        31 => "gdTransparent,8",
        39 => "$COLORS{$palette[2]},7",
        46 => "gdTransparent,6",
        52 => "$COLORS{$palette[2]},10",
        62 => "gdTransparent,3",
        65 => "$COLORS{$palette2[2]},4",
        69 => "gdTransparent,8",
        77 => "$COLORS{$palette[2]},6",
        83 => "gdTransparent,7"
      },
      q => {
        93  => "$COLORS{$palette[2]},2",
        95  => "gdTransparent,5",
        100 => "$COLORS{$palette[2]},6",
        106 => "gdTransparent,5",
        111 => "$COLORS{$palette2[2]},4",
        115 => "gdTransparent,2",
        117 => "$COLORS{$palette2[2]},4",
        121 => "gdTransparent,10",
        131 => "$COLORS{$palette[2]},10",
        141 => "gdTransparent,3",
        144 => "$COLORS{$palette[2]},10",
        154 => "gdTransparent,8",
        162 => "$COLORS{$palette[2]},10",
        172 => "gdTransparent,8",
        180 => "$COLORS{$palette[2]},8",
        188 => "gdTransparent,5",
        193 => "$COLORS{$palette[2]},7"
      }
    },

    3 => {
      p => {
        55  => "$COLORS{$palette[3]},2",
        57  => "gdTransparent,5",
        62  => "$COLORS{$palette[3]},7",
        69  => "gdTransparent,3",
        72  => "$COLORS{$palette[3]},4",
        76  => "gdTransparent,18",
        94  => "$COLORS{$palette[3]},12",
        106 => "gdTransparent,5",
        111 => "$COLORS{$palette[3]},11"
      },
      q => {
        125 => "$COLORS{$palette[3]},1",
        126 => "gdStyled,5",
        131 => "gdTransparent,3",
        134 => "$COLORS{$palette[3]},6",
        140 => "gdTransparent,3",
        143 => "$COLORS{$palette[3]},8",
        151 => "gdTransparent,8",
        159 => "$COLORS{$palette[3]},4",
        163 => "gdTransparent,5",
        168 => "$COLORS{$palette[3]},8",
        176 => "gdTransparent,4",
        180 => "$COLORS{$palette[3]},6",
        186 => "gdTransparent,3",
        189 => "$COLORS{$palette[3]},5",
        194 => "gdTransparent,5",
        199 => "$COLORS{$palette[3]},3"
      }
    },

    4 => {
      p => {
        70  => "gdTransparent,4",
        74  => "$COLORS{$palette[4]},4",
        78  => "gdTransparent,3",
        81  => "$COLORS{$palette[4]},5",
        86  => "gdTransparent,7",
        93  => "$COLORS{$palette2[4]},3",
        96  => "gdTransparent,3",
        99  => "$COLORS{$palette[4]},1"
      },
      q => {
        104 => "$COLORS{$palette[4]},2",
        105 => "gdTransparent,7",
        112 => "$COLORS{$palette[4]},10",
        122 => "gdTransparent,12",
        134 => "$COLORS{$palette[4]},7",
        141 => "gdTransparent,1",
        142 => "$COLORS{$palette2[4]},6",
        148 => "gdTransparent,3",
        151 => "$COLORS{$palette[4]},7",
        158 => "gdTransparent,3",
        161 => "$COLORS{$palette[4]},12",
        173 => "gdTransparent,4",
        177 => "$COLORS{$palette[4]},3",
        180 => "gdTransparent,5",
        185 => "$COLORS{$palette[4]},6",
        191 => "gdTransparent,4",
        195 => "$COLORS{$palette[4]},5"
      }
    },

    5 => {
      p => {
        80  => "$COLORS{$palette2[5]},3",
        83  => "gdTransparent,4",
        87  => "$COLORS{$palette[5]},10",
        97  => "gdTransparent,5",
        102 => "$COLORS{$palette[5]},3"
      },
      q => {
        109 => "$COLORS{$palette[5]},2",
        111 => "gdTransparent,6",
        117 => "$COLORS{$palette[5]},5",
        122 => "gdTransparent,10",
        132 => "$COLORS{$palette[5]},10",
        142 => "gdTransparent,4",
        146 => "$COLORS{$palette[5]},10",
        156 => "gdTransparent,4",
        160 => "$COLORS{$palette[5]},10",
        170 => "gdTransparent,12",
        182 => "$COLORS{$palette[5]},6",
        188 => "gdTransparent,5",
        193 => "$COLORS{$palette[5]},7"
      }
    },

    6 => {
      p => {
        85  => "$COLORS{$palette[6]},3",
        88  => "gdTransparent,5",
        93  => "$COLORS{$palette[6]},8",
        101 => "gdTransparent,7",
        108 => "$COLORS{$palette3[6]},2",
        110 => "gdTransparent,6",
        116 => "$COLORS{$palette[6]},8",
        124 => "gdTransparent,1",
      },
      q => {
        129 => "$COLORS{$palette[6]},8",
        137 => "gdTransparent,3",
        140 => "$COLORS{$palette[6]},6",
        146 => "gdTransparent,4",
        150 => "$COLORS{$palette[6]},7",
        157 => "gdTransparent,8",
        165 => "$COLORS{$palette[6]},12",
        177 => "gdTransparent,6",
        183 => "$COLORS{$palette[6]},7",
        190 => "gdTransparent,7",
        197 => "$COLORS{$palette2[6]},3"
      }
    },

    7 => {
      p => {
        310 => "$COLORS{$palette[7]},10",
        320 => "gdTransparent,7",
        327 => "$COLORS{$palette[7]},6",
        333 => "gdTransparent,5",
        338 => "$COLORS{$palette[7]},4",
        342 => "gdTransparent,3"
      },
      q => {
        349 => "$COLORS{$palette[7]},1",
        350 => "gdTransparent,14",
        364 => "$COLORS{$palette[7]},12",
        376 => "gdTransparent,10",
        386 => "$COLORS{$palette[7]},12",
        398 => "gdTransparent,6",
        404 => "$COLORS{$palette2[7]},4",
        408 => "gdTransparent,4",
        412 => "$COLORS{$palette[7]},3"
      }
    },

    8 => {
      p => {
        320 => "$COLORS{$palette[8]},6",
        326 => "gdTransparent,6",
        332 => "$COLORS{$palette[8]},7",
        339 => "gdTransparent,6"
      },
      q => {
        349 => "$COLORS{$palette[8]},2",
        351 => "gdTransparent,4",
        355 => "$COLORS{$palette[8]},6",
        361 => "gdTransparent,6",
        367 => "$COLORS{$palette[8]},7",
        374 => "gdTransparent,3",
        377 => "$COLORS{$palette[8]},7",
        384 => "gdTransparent,9",
        393 => "$COLORS{$palette[8]},9",
        402 => "gdTransparent,9",
        411 => "$COLORS{$palette[8]},4"
      }
    },

    9 => {
      p => {
        320 => "$COLORS{$palette[9]},6",
        326 => "gdTransparent,2",
        328 => "$COLORS{$palette[9]},7",
        335 => "gdTransparent,7",
        342 => "$COLORS{$palette2[9]},3"
      },
      q => {
        349 => "$COLORS{$palette[9]},1",
        350 => "gdStyled,14",
        364 => "gdTransparent,4",
        368 => "$COLORS{$palette[9]},15",
        382 => "gdTransparent,14",
        396 => "$COLORS{$palette[9]},8",
        404 => "gdTransparent,2",
        406 => "$COLORS{$palette[9]},5",
        411 => "gdTransparent,4"
      }
    },

    10 => {
      p => {
        320 => "$COLORS{$palette[10]},4",
        324 => "gdTransparent,5",
        329 => "$COLORS{$palette[10]},10",
        339 => "gdTransparent,6"
      },
      q => {
        349 => "$COLORS{$palette[10]},1",
        350 => "gdTransparent,7",
        357 => "$COLORS{$palette[10]},18",
        375 => "gdTransparent,12",
        387 => "$COLORS{$palette[10]},10",
        397 => "gdTransparent,10",
        407 => "$COLORS{$palette[10]},8"
      }
    },

    11 => {
      p => {
        328 => "$COLORS{$palette[11]},10",
        338 => "gdTransparent,4",
        342 => "$COLORS{$palette[11]},6",
        347 => "gdTransparent,8"
      },
      q => {
        359 => "$COLORS{$palette[11]},10",
        369 => "gdTransparent,12",
        381 => "$COLORS{$palette[11]},10",
        391 => "gdTransparent,3",
        394 => "$COLORS{$palette[11]},8",
        402 => "gdTransparent,11",
        413 => "$COLORS{$palette[11]},4"
      }
    },

    12 => {
      p => {
        332 => "$COLORS{$palette[12]},10",
        342 => "gdTransparent,8"
      },
      q => {
        354 => "$COLORS{$palette[12]},8",
        362 => "gdTransparent,10",
        372 => "$COLORS{$palette[12]},7",
        379 => "gdTransparent,4",
        383 => "$COLORS{$palette[12]},12",
        395 => "gdTransparent,7",
        402 => "$COLORS{$palette[12]},6",
        408 => "gdTransparent,7",
        415 => "$COLORS{$palette[12]},2"
      }
    },

    13 => {
      p => {
        541 => "$COLORS{$palette[13]},1",
      },
      q => {
        554 => "$COLORS{$palette[13]},2",
        556 => "gdTransparent,8",
        564 => "$COLORS{$palette[13]},5",
        569 => "gdTransparent,8",
        577 => "$COLORS{$palette[13]},14",
        591 => "gdTransparent,6",
        597 => "$COLORS{$palette[13]},8",
        605 => "gdTransparent,7",
        612 => "$COLORS{$palette[13]},4"
      }
    },

    14 => {
      p => {
        543 => "$COLORS{$palette[14]},1",
      },
      q => {
        556 => "$COLORS{$palette[14]},2",
        558 => "gdTransparent,6",
        564 => "$COLORS{$palette[14]},6",
        570 => "gdTransparent,5",
        575 => "$COLORS{$palette[14]},11",
        586 => "gdTransparent,6",
        592 => "$COLORS{$palette[14]},3",
        595 => "gdTransparent,14",
        609 => "$COLORS{$palette[14]},6"
      }
    },

    15 => {
      p => {
        540 => "$COLORS{$palette[15]},1",
      },
      q => {
        559 => "gdTransparent,2",
        561 => "$COLORS{$palette2[15]},2",
        563 => "gdTransparent,2",
        565 => "$COLORS{$palette[15]},5",
        571 => "gdTransparent,7",
        578 => "$COLORS{$palette[15]},12",
        590 => "gdTransparent,8",
        598 => "$COLORS{$palette3[15]},4",
        602 => "gdTransparent,8",
        610 => "$COLORS{$palette[15]},5"
      }
    },

    16 => {
      p => {
        559 => "$COLORS{$palette2[16]},3",
        562 => "gdTransparent,5",
        567 => "$COLORS{$palette[16]},6",
        573 => "gdTransparent,7"
      },
      q => {
        584 => "$COLORS{$palette[16]},1",
        585 => "gdStyled,10",
        595 => "$COLORS{$palette2[16]},1",
        596 => "gdTransparent,4",
        600 => "$COLORS{$palette[16]},5",
        605 => "gdTransparent,6",
        611 => "$COLORS{$palette[16]},5"
      }
    },

    17 => {
      p => {
        563 => "$COLORS{$palette[17]},6",
        569 => "gdTransparent,7"
      },
      q => {
        579 => "$COLORS{$palette[17]},1",
        580 => "gdTransparent,3",
        583 => "$COLORS{$palette2[17]},5",
        588 => "gdTransparent,11",
        599 => "$COLORS{$palette[17]},7",
        606 => "gdTransparent,3",
        609 => "$COLORS{$palette[17]},7"
      }
    },

    18 => {
      p => {
        566 => "gdTransparent,9"
      },
      q => {
        579 => "gdTransparent,8",
        587 => "$COLORS{$palette[18]},10",
        597 => "gdTransparent,12",
        609 => "$COLORS{$palette[18]},6"
      }
    },

    19 => {
      p => {
        775 => "$COLORS{$palette2[19]},6",
        781 => "gdTransparent,6",
        787 => "gdStyled,3"
      },
      q => {
        794 => "gdStyled,3",
        797 => "gdTransparent,8",
        805 => "$COLORS{$palette[19]},5",
        810 => "gdTransparent,5"
      }
    },

    20 => {
      p => {
        775 => "$COLORS{$palette[20]},7",
        782 => "gdTransparent,8"
      },
      q => {
        794 => "$COLORS{$palette[20]},1",
        795 => "gdTransparent,5",
        800 => "$COLORS{$palette[20]},4",
        804 => "gdTransparent,5",
        809 => "$COLORS{$palette[20]},5"
      }
    },

    21 => {
      p => {
        784 => "$COLORS{$palette[21]},1"
      },
      q => {
        795 => "$COLORS{$palette[21]},2",
        797 => "gdTransparent,3",
        800 => "$COLORS{$palette[21]},9"
      }
    },

    22 => {
      p => {
        779 => "$COLORS{$palette[22]},1",
        782 => "$COLORS{$palette[22]},1"
      },
      q => {
        794 => "$COLORS{$palette[22]},1",
        795 => "gdTransparent,7",
        802 => "$COLORS{$palette[22]},6"
      }
    },

    X => {
      p => {
        710 => "$COLORS{$palette[23]},3",
        713 => "gdTransparent,7",
        720 => "$COLORS{$palette[23]},12",
        732 => "gdTransparent,3",
        735 => "$COLORS{$palette[23]},3",
        738 => "gdTransparent,7"
      },
      q => {
        749 => "$COLORS{$palette[23]},2",
        751 => "$COLORS{$palette2[23]},3",
        754 => "gdTransparent,9",
        763 => "$COLORS{$palette[23]},15",
        778 => "gdTransparent,5",
        783 => "$COLORS{$palette[23]},6",
        789 => "gdTransparent,5",
        794 => "$COLORS{$palette[23]},7",
        801 => "gdTransparent,6",
        807 => "$COLORS{$palette[23]},7"
      }
    },

    Y => {
      p => {
        774 => "$COLORS{$palette[24]},2",
        776 => "gdTransparent,6"
      },
      q => {
        785 => "$COLORS{$palette[24]},1",
        786 => "gdTransparent,16",
        802 => "gdStyled,15"
      }
    }
  );

# Chromosome X positions
  %X = (
     1  => 100,
     2  => 200,
     3  => 300,
     4  => 400,
     5  => 500,
     6  => 600,

     7  => 100,
     8  => 200,
     9  => 300,
     10 => 400,
     11 => 500,
     12 => 600,

     13 => 100,
     14 => 200,
     15 => 300,
     16 => 400,
     17 => 500,
     18 => 600,

     19 => 100,
     20 => 200,
     21 => 300,
     22 => 400,
     X  => 500,
     Y  => 600
  );

# Chromosome Y positions
  %Y = (
     1  => "15,97,106,200,97,98",
     2  => "25,90,93,200,90,93",
     3  => "55,122,125,200",
     4  => "70,100,104,200",
     5  => "80,105,109,200",
     6  => "85,125,129,200",

     7  => "310,345,349,415",
     8  => "320,345,349,415",
     9  => "320,345,349,415",
     10 => "320,345,349,415",
     11 => "320,355,359,415",
     12 => "330,350,354,415",

     13 => "554,615,549",
     14 => "556,615,551",
     15 => "559,615,550",
     16 => "560,580,584,615",
     17 => "563,576,579,615",
     18 => "565,575,579,615",

     19 => "775,790,794,815",
     20 => "775,790,794,815",
     21 => "784,785,795,813",
     22 => "779,780,782,783,794,813,789",

     X  => "710,745,749,813",
     Y  => "774,782,785,815"
  );

  %YP = (
    13 => {
      1 => "550,549,548,546,545,545,546,548,549,550",
      2 => "534,534,536,538,538,536"
    },
    14 => {
      1 => "552,551,550,548,547,547,548,550,551,552",
      2 => "536,536,538,540,540,538"
    },
    15 => {
      1 => "550,549,548,546,545,545,546,548,549,550",
      2 => "533,533,535,537,537,535"
    },
    21 => {
      1 => "792,791,790,788,787,787,788,790,791,792",
      2 => "778,778,780,782,782,780"
    },
    22 => {
      1 => "790,789,788,787,786,786,785,785,784,784,784,784,784,785,785,786,786,787,788,789,790",
      2 => "773,773,775,777,777,775"
    },
    Y  => {
      1 => "818,819,819,820,821,821,822,822,823,823,823,823,823,822,822,821,821,820,819,819,818"
    }
  );

  return $im;
}

######################################################################
sub DrawGrid4 {
  my ($im, $karyotype) = @_;

  my ($bottom, $top, $slide, $chrom);

  my $diag = new GD::Image(200,200); 
  my $white = $diag->colorAllocate(255,255,255);
  my $black = $diag->colorAllocate(0,0,0);
  $diag->transparent($white);
  $im->setBrush($diag);

# my $soft = 400 - ((length $karyotype) / 2);
# $im->string(gdMediumBoldFont,$soft,0,"$karyotype",$COLORS{black});

  my ($count, $gender, $abnorm) = split(",", $karyotype, 3);
  $abnorm =~ s/$/ /;
  $abnorm =~ s/,/ /g;

  if ($gender eq 'XXX') {
    $abnorm .= $abnorm . '+X ';
  } elsif ($gender eq 'XXXX') {
    $abnorm .= $abnorm . '+X +X ';
  } elsif ($gender eq 'XXY') {
    $abnorm .= $abnorm . '+X ';
  } elsif ($gender eq 'XYY') {
    $abnorm .= $abnorm . '+Y ';
  } elsif ($gender eq 'XXYY') {
    $abnorm .= $abnorm . '+X +Y ';
  }

  $top = 0;
  $bottom = 220;
  if ($abnorm !~ /-1 /) {
    Chromosome_1($im, $bottom, $top, $X{1}, $Y{1});
  } else {
    $im->string(gdMediumBoldFont,$X{1}+46,$bottom,"1",$COLORS{$palette[1]});
  }
  if ($abnorm !~ /-2 /) {
    Chromosome_2($im, $bottom, $top, $X{2}, $Y{2});
  } else {
    $im->string(gdMediumBoldFont,$X{2}+46,$bottom,"2",$COLORS{$palette[2]});
  }
  if ($abnorm !~ /-3 /) {
    Chromosome_3($im, $bottom, $top, $X{3}, $Y{3});
  } else {
    $im->string(gdMediumBoldFont,$X{3}+46,$bottom,"3",$COLORS{$palette[3]});
  }
  if ($abnorm !~ /-4 /) {
    Chromosome_4($im, $bottom, $top, $X{4}, $Y{4});
  } else {
    $im->string(gdMediumBoldFont,$X{4}+46,$bottom,"4",$COLORS{$palette[4]});
  }
  if ($abnorm !~ /-5 /) {
    Chromosome_5($im, $bottom, $top, $X{5}, $Y{5});
  } else {
    $im->string(gdMediumBoldFont,$X{5}+46,$bottom,"5",$COLORS{$palette[5]});
  }
  if ($abnorm !~ /-6 /) {
    Chromosome_6($im, $bottom, $top, $X{6}, $Y{6});
  } else {
    $im->string(gdMediumBoldFont,$X{6}+46,$bottom,"6",$COLORS{$palette[6]});
  }

  $bottom = 440;
  if ($abnorm !~ /-7 /) {
    Chromosome_7($im,  $bottom, $top, $X{7}, $Y{7});
  } else {
    $im->string(gdMediumBoldFont,$X{7}+46,$bottom,"7",$COLORS{$palette[7]});
  }
  if ($abnorm !~ /-8 /) {
    Chromosome_8($im,  $bottom, $top, $X{8}, $Y{8});
  } else {
    $im->string(gdMediumBoldFont,$X{8}+46,$bottom,"8",$COLORS{$palette[8]});
  }
  if ($abnorm !~ /-9 /) {
    Chromosome_9($im,  $bottom, $top, $X{9}, $Y{9});
  } else {
    $im->string(gdMediumBoldFont,$X{9}+46,$bottom,"9",$COLORS{$palette[9]});
  }
  if ($abnorm !~ /-10 /) {
    Chromosome_10($im, $bottom, $top, $X{10}, $Y{10});
  } else {
    $im->string(gdMediumBoldFont,$X{10}+46,$bottom,"10",$COLORS{$palette[10]});
  }
  if ($abnorm !~ /-11 /) {
    Chromosome_11($im, $bottom, $top, $X{11}, $Y{11});
  } else {
    $im->string(gdMediumBoldFont,$X{11}+46,$bottom,"11",$COLORS{$palette[11]});
  }
  if ($abnorm !~ /-12 /) {
    Chromosome_12($im, $bottom, $top, $X{12}, $Y{12});
  } else {
    $im->string(gdMediumBoldFont,$X{12}+46,$bottom,"12",$COLORS{$palette[12]});
  }

  $bottom = 640;
  if ($abnorm !~ /-13 /) {
    Chromosome_13($im, $bottom, $top, $X{13}, $Y{13});
  } else {
    $im->string(gdMediumBoldFont,$X{13}+46,$bottom,"13",$COLORS{$palette[13]});
  }
  if ($abnorm !~ /-14 /) {
    Chromosome_14($im, $bottom, $top, $X{14}, $Y{14});
  } else {
    $im->string(gdMediumBoldFont,$X{14}+46,$bottom,"14",$COLORS{$palette[14]});
  }
  if ($abnorm !~ /-15 /) {
    Chromosome_15($im, $bottom, $top, $X{15}, $Y{15});
  } else {
    $im->string(gdMediumBoldFont,$X{15}+46,$bottom,"15",$COLORS{$palette[15]});
  }
  if ($abnorm !~ /-16 /) {
    Chromosome_16($im, $bottom, $top, $X{16}, $Y{16});
  } else {
    $im->string(gdMediumBoldFont,$X{16}+46,$bottom,"16",$COLORS{$palette[16]});
  }
  if ($abnorm !~ /-17 /) {
    Chromosome_17($im, $bottom, $top, $X{17}, $Y{17});
  } else {
    $im->string(gdMediumBoldFont,$X{17}+46,$bottom,"17",$COLORS{$palette[17]});
  }
  if ($abnorm !~ /-18 /) {
    Chromosome_18($im, $bottom, $top, $X{18}, $Y{18});
  } else {
    $im->string(gdMediumBoldFont,$X{18}+46,$bottom,"18",$COLORS{$palette[18]});
  }

  $bottom = 840;
  if ($abnorm !~ /-19 /) {
    Chromosome_19($im, $bottom, $top, $X{19}, $Y{19});
  } else {
    $im->string(gdMediumBoldFont,$X{19}+46,$bottom,"19",$COLORS{$palette[19]});
  }
  if ($abnorm !~ /-20 /) {
    Chromosome_20($im, $bottom, $top, $X{20}, $Y{20});
  } else {
    $im->string(gdMediumBoldFont,$X{20}+46,$bottom,"20",$COLORS{$palette[20]});
  }
  if ($abnorm !~ /-21 /) {
    Chromosome_21($im, $bottom, $top, $X{21}, $Y{21});
  } else {
    $im->string(gdMediumBoldFont,$X{21}+46,$bottom,"21",$COLORS{$palette[21]});
  }
  if ($abnorm !~ /-22 /) {
    Chromosome_22($im, $bottom, $top, $X{22}, $Y{22});
  } else {
    $im->string(gdMediumBoldFont,$X{22}+46,$bottom,"22",$COLORS{$palette[22]});
  }
  Chromosome_X($im,  $bottom, $top, $X{'X'}, $Y{'X'});

  # for the Y position
  if ($gender eq 'XX') {
    if ($abnorm !~ /-X /) {
      Chromosome_X($im, $bottom, $top, $X{'Y'}, $Y{'X'});
    } else {
      $im->string(gdMediumBoldFont,$X{'X'}+46,$bottom,"X",$COLORS{$palette[23]});
    }
  } elsif (($gender eq 'XXX') || ($gender eq 'XXXX')) {
    Chromosome_X($im, $bottom, $top, $X{'Y'}, $Y{'X'});
  } elsif (($gender eq 'XY') ||
           ($gender eq 'XXY') || ($gender eq 'XYY') || ($gender eq 'XXYY')) {
    Chromosome_Y($im, $bottom, $top, $X{'Y'}, $Y{'Y'});
  }

# $top = 900;
  $slide = 25;
  while ($abnorm =~ /\+/) {
#   $bottom = 1120;
    $bottom = 220;
    if ($abnorm =~ /\+1 /) {
      Chromosome_1($im, $bottom, $top, $X{1}+$slide, $Y{1});
      $abnorm =~ s/\+1 //;
    }
    if ($abnorm =~ /\+2 /) {
      Chromosome_2($im, $bottom, $top, $X{2}+$slide, $Y{2});
      $abnorm =~ s/\+2 //;
    }
    if ($abnorm =~ /\+3 /) {
      Chromosome_3($im, $bottom, $top, $X{3}+$slide, $Y{3});
      $abnorm =~ s/\+3 //;
    }
    if ($abnorm =~ /\+4 /) {
      Chromosome_4($im, $bottom, $top, $X{4}+$slide, $Y{4});
      $abnorm =~ s/\+4 //;
    }
    if ($abnorm =~ /\+5 /) {
      Chromosome_5($im, $bottom, $top, $X{5}+$slide, $Y{5});
      $abnorm =~ s/\+5 //;
    }
    if ($abnorm =~ /\+6 /) {
      Chromosome_6($im, $bottom, $top, $X{6}+$slide, $Y{6});
      $abnorm =~ s/\+6 //;
    }

#   $bottom = 1340;
    $bottom = 440;
    if ($abnorm =~ /\+7 /) {
      Chromosome_7($im,  $bottom, $top, $X{7}+$slide, $Y{7});
      $abnorm =~ s/\+7 //;
    }
    if ($abnorm =~ /\+8 /) {
      Chromosome_8($im,  $bottom, $top, $X{8}+$slide, $Y{8});
      $abnorm =~ s/\+8 //;
    }
    if ($abnorm =~ /\+9 /) {
      Chromosome_9($im,  $bottom, $top, $X{9}+$slide, $Y{9});
      $abnorm =~ s/\+9 //;
    }
    if ($abnorm =~ /\+10 /) {
      Chromosome_10($im, $bottom, $top, $X{10}+$slide, $Y{10});
      $abnorm =~ s/\+10 //;
    }
    if ($abnorm =~ /\+11 /) {
      Chromosome_11($im, $bottom, $top, $X{11}+$slide, $Y{11});
      $abnorm =~ s/\+11 //;
    }
    if ($abnorm =~ /\+12 /) {
      Chromosome_12($im, $bottom, $top, $X{12}+$slide, $Y{12});
      $abnorm =~ s/\+12 //;
    }

#   $bottom = 1540;
    $bottom = 640;
    if ($abnorm =~ /\+13 /) {
      Chromosome_13($im, $bottom, $top, $X{13}+$slide, $Y{13});
      $abnorm =~ s/\+13 //;
    }
    if ($abnorm =~ /\+14 /) {
      Chromosome_14($im, $bottom, $top, $X{14}+$slide, $Y{14});
      $abnorm =~ s/\+14 //;
    }
    if ($abnorm =~ /\+15 /) {
      Chromosome_15($im, $bottom, $top, $X{15}+$slide, $Y{15});
      $abnorm =~ s/\+15 //;
    }
    if ($abnorm =~ /\+16 /) {
      Chromosome_16($im, $bottom, $top, $X{16}+$slide, $Y{16});
      $abnorm =~ s/\+16 //;
    }
    if ($abnorm =~ /\+17 /) {
      Chromosome_17($im, $bottom, $top, $X{17}+$slide, $Y{17});
      $abnorm =~ s/\+17 //;
    }
    if ($abnorm =~ /\+18 /) {
      Chromosome_18($im, $bottom, $top, $X{18}+$slide, $Y{18});
      $abnorm =~ s/\+18 //;
    }

#   $bottom = 1740;
    $bottom = 840;
    if ($abnorm =~ /\+19 /) {
      Chromosome_19($im, $bottom, $top, $X{19}+$slide, $Y{19});
      $abnorm =~ s/\+19 //;
    }
    if ($abnorm =~ /\+20 /) {
      Chromosome_20($im, $bottom, $top, $X{20}+$slide, $Y{20});
      $abnorm =~ s/\+20 //;
    }
    if ($abnorm =~ /\+21 /) {
      Chromosome_21($im, $bottom, $top, $X{21}+$slide, $Y{21});
      $abnorm =~ s/\+21 //;
    }
    if ($abnorm =~ /\+22 /) {
      Chromosome_22($im, $bottom, $top, $X{22}+$slide, $Y{22});
      $abnorm =~ s/\+22 //;
    }
    if ($abnorm =~ /\+X /) {
      Chromosome_X($im,  $bottom, $top, $X{'X'}+$slide, $Y{'X'});
      $abnorm =~ s/\+X //;
    }
    if ($abnorm =~ /\+Y /) {
      Chromosome_Y($im,  $bottom, $top, $X{'Y'}+$slide, $Y{'Y'});
      $abnorm =~ s/\+Y //;
    }
    $slide += 25;
  }

  if ($abnorm =~ /inv\((\d+)\)/) {
    $chrom = $1;
    Arrow($im, $chrom);
    $abnorm =~ s/inv\(\d+\) //;
  }
}

### Chromosome 1
sub Chromosome_1 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[1]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd, $ye, $yf) = split ",", $Y;
  $ya += $top; $yb += $top; $yc += $top;
  $yd += $top; $ye += $top; $yf += $top;

  $im->filledArc($X+50,$yc,20,20,180,360,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr (1) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }

     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # middle
  $y0 = $ye;
  $y1 = $yf;
  $x0 = $X + 45;
  $x1 = $X + 55;

  $im->filledRectangle (
      $x0,
      $y0,
      $x1,
      $y1,
      $chromColor
  );

  $im->arc($X+50,$ya,20,16,180,360,$chromColor);
  $im->arc($X+50,$yd,20,14,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"1",$chromColor);
}

### Chromosome 2
sub Chromosome_2 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[2]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  for $chr (2) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }

  my ($ya, $yb, $yc, $yd, $ye, $yf) = split ",", $Y;
  $ya += $top; $yb += $top; $yc += $top;
  $yd += $top; $ye += $top; $yf += $top;

     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # middle
  $y0 = $ye;
  $y1 = $yf;
  $x0 = $X + 44;
  $x1 = $X + 56;

  $im->filledRectangle (
      $x0,
      $y0,
      $x1,
      $y1,
      $chromColor
  );

  $im->arc($X+50,$ya,20,17,180,360,$chromColor);
  $im->arc($X+50,$yd,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"2",$chromColor);
}

### Chromosome 3
sub Chromosome_3 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[3]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-3,15,15,20,160,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr (3) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->filledRectangle($X+46,$ya-2,$X+54,$ya-1,$chromColor);
  $im->arc($X+50,$yd,20,15,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"3",$chromColor);
}

### Chromosome 4
sub Chromosome_4 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[4]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);

  for $chr (4) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,20,180,360,$chromColor);
  $im->arc($X+50,$yd,20,16,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"4",$chromColor);
}

### Chromosome 5
sub Chromosome_5 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[5]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);

  for $chr (5) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }

     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,18,180,360,$chromColor);
  $im->arc($X+50,$yd,20,17,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"5",$chromColor);
}

### Chromosome 6
sub Chromosome_6 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[6]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);

  for $chr (6) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,18,180,360,$chromColor);
  $im->arc($X+50,$yd,20,18,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"6",$chromColor);
}

### Chromosome 7
sub Chromosome_7 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[7]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);

  for $chr (7) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,17,180,360,$chromColor);
  $im->arc($X+50,$yd,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"7",$chromColor);
}

### Chromosome 8
sub Chromosome_8 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[8]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);

  for $chr (8) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,20,180,360,$chromColor);
  $im->arc($X+50,$yd,20,14,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"8",$chromColor);
}

### Chromosome 9
sub Chromosome_9 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[9]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr (9) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,15,180,360,$chromColor);
  $im->arc($X+50,$yd,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"9",$chromColor);
}

### Chromosome 10
sub Chromosome_10 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[10]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);

  for $chr (10) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,17,180,360,$chromColor);
  $im->arc($X+50,$yd,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"10",$chromColor);
}

### Chromosome 11
sub Chromosome_11 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[11]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);

  for $chr (11) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,20,180,360,$chromColor);
  $im->arc($X+50,$yd,20,15,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"11",$chromColor);
}

### Chromosome 12
sub Chromosome_12 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[12]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);

  for $chr (12) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,20,180,360,$chromColor);
  $im->arc($X+50,$yd,20,18,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"12",$chromColor);
}

### Chromosome 13
sub Chromosome_13 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1, $y);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[13]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc) = split ",", $Y;
  $ya += $top; $yb += $top; $yc += $top;

  my @yp1 = split ",", $YP{13}{1};
  my @yp2 = split ",", $YP{13}{2};
  for $y (@yp1) {
    $y += $top;
  }
  for $y (@yp2) {
    $y += $top;
  }

  $im->filledArc($X+50,$yc,15,15,0,180,$chromColor);

  for $chr (13) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }

     # bottom
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->setStyle($COLORS{mediumgray},$COLORS{mediumgray},
                $COLORS{mediumgray},$COLORS{mediumgray},
                $chromColor, $chromColor,
                $chromColor, $chromColor);

  $poly = new GD::Polygon;
  $poly->addPt($X+41,$yp1[0]);
  $poly->addPt($X+41,$yp1[1]);
  $poly->addPt($X+42,$yp1[2]);
  $poly->addPt($X+43,$yp1[3]);
  $poly->addPt($X+45,$yp1[4]);
  $poly->addPt($X+55,$yp1[5]);
  $poly->addPt($X+57,$yp1[6]);
  $poly->addPt($X+58,$yp1[7]);
  $poly->addPt($X+59,$yp1[8]);
  $poly->addPt($X+59,$yp1[9]);
  $im->filledPolygon($poly,gdStyled);

  $im->arc($X+50,$yb,20,16,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"13",$chromColor);

  $poly = new GD::Polygon;
  $poly->addPt($X+43,$yp2[0]);
  $poly->addPt($X+57,$yp2[1]);
  $poly->addPt($X+59,$yp2[2]);
  $poly->addPt($X+57,$yp2[3]);
  $poly->addPt($X+43,$yp2[4]);
  $poly->addPt($X+41,$yp2[5]);
  $im->filledPolygon($poly,gdStyled);
}

### Chromosome 14
sub Chromosome_14 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1, $y);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[14]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc) = split ",", $Y;
  $ya += $top; $yb += $top; $yc += $top;

  my @yp1 = split ",", $YP{14}{1};
  my @yp2 = split ",", $YP{14}{2};
  for $y (@yp1) {
    $y += $top;
  }
  for $y (@yp2) {
    $y += $top;
  }

  $im->filledArc($X+50,$yc,18,12,0,180,$chromColor);

  for $chr (14) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }

     # bottom
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->setStyle($COLORS{mediumgray},$COLORS{mediumgray},
                $COLORS{mediumgray},$COLORS{mediumgray},
                $chromColor, $chromColor,
                $chromColor, $chromColor);

  $poly = new GD::Polygon;
  $poly->addPt($X+41,$yp1[0]);
  $poly->addPt($X+41,$yp1[1]);
  $poly->addPt($X+42,$yp1[2]);
  $poly->addPt($X+43,$yp1[3]);
  $poly->addPt($X+45,$yp1[4]);
  $poly->addPt($X+55,$yp1[5]);
  $poly->addPt($X+57,$yp1[6]);
  $poly->addPt($X+58,$yp1[7]);
  $poly->addPt($X+59,$yp1[8]);
  $poly->addPt($X+59,$yp1[9]);
  $im->filledPolygon($poly,gdStyled);

  $im->arc($X+50,$yb,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"14",$chromColor);

  $poly = new GD::Polygon;
  $poly->addPt($X+43,$yp2[0]);
  $poly->addPt($X+57,$yp2[1]);
  $poly->addPt($X+59,$yp2[2]);
  $poly->addPt($X+57,$yp2[3]);
  $poly->addPt($X+43,$yp2[4]);
  $poly->addPt($X+41,$yp2[5]);
  $im->filledPolygon($poly,gdStyled);
}

### Chromosome 15
sub Chromosome_15 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1, $y);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[15]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc) = split ",", $Y;
  $ya += $top; $yb += $top; $yc += $top;

  my @yp1 = split ",", $YP{15}{1};
  my @yp2 = split ",", $YP{15}{2};
  for $y (@yp1) {
    $y += $top;
  }
  for $y (@yp2) {
    $y += $top;
  }

  $im->filledArc($X+50,$yc,18,10,0,180,$chromColor);
  $im->filledArc($X+50,$ya,18,10,180,360,$chromColor);

  for $chr (15) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }

     # bottom
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->setStyle($COLORS{mediumgray},$COLORS{mediumgray},
                $COLORS{mediumgray},$COLORS{mediumgray},
                $chromColor, $chromColor,
                $chromColor, $chromColor);

  $poly = new GD::Polygon;
  $poly->addPt($X+41,$yp1[0]);
  $poly->addPt($X+41,$yp1[1]);
  $poly->addPt($X+42,$yp1[2]);
  $poly->addPt($X+43,$yp1[3]);
  $poly->addPt($X+45,$yp1[4]);
  $poly->addPt($X+55,$yp1[5]);
  $poly->addPt($X+57,$yp1[6]);
  $poly->addPt($X+58,$yp1[7]);
  $poly->addPt($X+59,$yp1[8]);
  $poly->addPt($X+59,$yp1[9]);
  $im->filledPolygon($poly,gdStyled);

  $im->arc($X+50,$yb,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"15",$chromColor);

  $poly = new GD::Polygon;
  $poly->addPt($X+43,$yp2[0]);
  $poly->addPt($X+57,$yp2[1]);
  $poly->addPt($X+59,$yp2[2]);
  $poly->addPt($X+57,$yp2[3]);
  $poly->addPt($X+43,$yp2[4]);
  $poly->addPt($X+41,$yp2[5]);
  $im->filledPolygon($poly,gdStyled);
}

### Chromosome 16
sub Chromosome_16 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[16]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr (16) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,17,180,360,$chromColor);
  $im->arc($X+50,$yd,20,17,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"16",$chromColor);
}

### Chromosome 17
sub Chromosome_17 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[17]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-2,15,15,20,160,$chromColor);

  for $chr (17) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,20,180,360,$chromColor);
  $im->arc($X+50,$yd,20,16,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"17",$chromColor);
}

### Chromosome 18
sub Chromosome_18 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[18]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);

  for $chr (18) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->filledArc($X+50,$ya,20,20,180,360,$chromColor);
  $im->arc($X+50,$yd,20,16,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"18",$chromColor);
}

### Chromosome 19
sub Chromosome_19 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[19]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr (19) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,20,180,360,$chromColor);
  $im->filledArc($X+50,$yd,20,15,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"19",$chromColor);
}

### Chromosome 20
sub Chromosome_20 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[20]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledArc($X+50,$yb-1,15,15,20,160,$chromColor);

  for $chr (20) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,18,180,360,$chromColor);
  $im->arc($X+50,$yd,20,14,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"20",$chromColor);
}

### Chromosome 21
sub Chromosome_21 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1, $y);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[21]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  my @yp1 = split ",", $YP{21}{1};
  my @yp2 = split ",", $YP{21}{2};
  for $y (@yp1) {
    $y += $top;
  }
  for $y (@yp2) {
    $y += $top;
  }

  $im->filledArc($X+50,$yb+4,15,15,20,160,$chromColor);

  for $chr (21) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->setStyle($COLORS{$palette2[21]},$COLORS{$palette2[21]},
                $COLORS{$palette2[21]},$COLORS{$palette2[21]},
                $chromColor, $chromColor,
                $chromColor, $chromColor);

  $poly = new GD::Polygon;
  $poly->addPt($X+41,$yp1[0]);
  $poly->addPt($X+41,$yp1[1]);
  $poly->addPt($X+42,$yp1[2]);
  $poly->addPt($X+43,$yp1[3]);
  $poly->addPt($X+45,$yp1[4]);
  $poly->addPt($X+55,$yp1[5]);
  $poly->addPt($X+57,$yp1[6]);
  $poly->addPt($X+58,$yp1[7]);
  $poly->addPt($X+59,$yp1[8]);
  $poly->addPt($X+59,$yp1[9]);
  $im->filledPolygon($poly,gdStyled);

  $im->arc($X+50,$yd+2,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"21",$chromColor);

  $poly = new GD::Polygon;
  $poly->addPt($X+43,$yp2[0]);
  $poly->addPt($X+57,$yp2[1]);
  $poly->addPt($X+59,$yp2[2]);
  $poly->addPt($X+57,$yp2[3]);
  $poly->addPt($X+43,$yp2[4]);
  $poly->addPt($X+41,$yp2[5]);
  $im->filledPolygon($poly,gdStyled);
}

### Chromosome 22
sub Chromosome_22 {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1, $y);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[22]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd, $ye, $yf, $yg) = split ",", $Y;
  $ya += $top; $yb += $top; $yc += $top;
  $yd += $top; $ye += $top; $yf += $top; $yg += $top;

  my @yp1 = split ",", $YP{22}{1};
  my @yp2 = split ",", $YP{22}{2};
  for $y (@yp1) {
    $y += $top;
  }
  for $y (@yp2) {
    $y += $top;
  }

  $im->filledArc($X+50,$yg,15,15,20,160,$chromColor);

  for $chr (22) {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $ye;
  $y1 = $yf;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->setStyle($COLORS{$palette2[22]},$COLORS{$palette2[22]},
                $COLORS{$palette2[22]},$COLORS{$palette2[22]},
                $chromColor, $chromColor,
                $chromColor, $chromColor);

  $poly = new GD::Polygon;
  $poly->addPt($X+41,$yp1[0]);
  $poly->addPt($X+41,$yp1[1]);
  $poly->addPt($X+42,$yp1[2]);
  $poly->addPt($X+43,$yp1[3]);
  $poly->addPt($X+44,$yp1[4]);
  $poly->addPt($X+45,$yp1[5]);
  $poly->addPt($X+46,$yp1[6]);
  $poly->addPt($X+47,$yp1[7]);
  $poly->addPt($X+48,$yp1[8]);
  $poly->addPt($X+49,$yp1[9]);
  $poly->addPt($X+50,$yp1[10]);
  $poly->addPt($X+51,$yp1[11]);
  $poly->addPt($X+52,$yp1[12]);
  $poly->addPt($X+53,$yp1[13]);
  $poly->addPt($X+54,$yp1[14]);
  $poly->addPt($X+55,$yp1[15]);
  $poly->addPt($X+56,$yp1[16]);
  $poly->addPt($X+57,$yp1[17]);
  $poly->addPt($X+58,$yp1[18]);
  $poly->addPt($X+59,$yp1[19]);
  $poly->addPt($X+59,$yp1[20]);
  $im->filledPolygon($poly,gdStyled);

  $im->arc($X+50,$yf+2,20,20,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"22",$chromColor);

  $poly = new GD::Polygon;
  $poly->addPt($X+43,$yp2[0]);
  $poly->addPt($X+57,$yp2[1]);
  $poly->addPt($X+59,$yp2[2]);
  $poly->addPt($X+57,$yp2[3]);
  $poly->addPt($X+43,$yp2[4]);
  $poly->addPt($X+41,$yp2[5]);
  $im->filledPolygon($poly,gdStyled);
}

### Chromosome X
sub Chromosome_X {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[23]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  $im->filledRectangle($X+45,$yb+2,$X+55,$yb+4,$chromColor);

  for $chr ('X') {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          $shade
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->arc($X+50,$ya,20,14,180,360,$chromColor);
  $im->arc($X+50,$yd,20,14,0,180,$chromColor);
  $im->string(gdMediumBoldFont,$x0+5,$bottom,"X",$chromColor);
}

### Chromosome Y
sub Chromosome_Y {
  my ($im, $bottom, $top, $X, $Y) = @_;
  my ($x0, $x1, $y0, $y1, $y);
  my ($chr, $arm, $band, $shade, $bp, $shade_bp);
  my ($poly, $chromColor);

  $chromColor = $COLORS{$palette[24]};
  $x0 = $X + 41;
  $x1 = $X + 59;

  my ($ya, $yb, $yc, $yd) = split ",", $Y;
  $ya += $top; $yb += $top;
  $yc += $top; $yd += $top;

  my @yp1 = split ",", $YP{'Y'}{1};
  for $y (@yp1) {
    $y += $top;
  }

  $im->filledArc($X+50,$yb-3,15,15,20,160,$chromColor);
  $im->setStyle($COLORS{white},$COLORS{white},
                $chromColor,$chromColor);

  for $chr ('Y') {
    for $arm (keys %{$bands{$chr}}) {
      for $band (keys %{$bands{$chr}{$arm}}) {
        $shade_bp = $bands{$chr}{$arm}{$band};
        ($shade,$bp) = split ",", $shade_bp;
        $y0 = $band + $top;
        $y1 = $y0 + $bp;
        $im->filledRectangle (
          $x0,
          $y0,
          $x1,
          $y1,
          (($shade eq 'gdStyled') ? gdStyled : $shade)
        );
      }
    }
  }
     # top
  $y0 = $ya;
  $y1 = $yb;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

     # bottom
  $y0 = $yc;
  $y1 = $yd;
  $im->line($x0,$y0,$x0,$y1,$chromColor);
  $im->line($x1,$y0,$x1,$y1,$chromColor);

  $im->filledRectangle($X+45,$ya-3,$X+55,$ya-2,$chromColor);
  $im->arc($X+50,$yd,20,20,0,180,$chromColor);
  $poly = new GD::Polygon;
  $poly->addPt($X+41,$yp1[0]);
  $poly->addPt($X+41,$yp1[1]);
  $poly->addPt($X+42,$yp1[2]);
  $poly->addPt($X+43,$yp1[3]);
  $poly->addPt($X+44,$yp1[4]);
  $poly->addPt($X+45,$yp1[5]);
  $poly->addPt($X+46,$yp1[6]);
  $poly->addPt($X+47,$yp1[7]);
  $poly->addPt($X+48,$yp1[8]);
  $poly->addPt($X+49,$yp1[9]);
  $poly->addPt($X+50,$yp1[10]);
  $poly->addPt($X+51,$yp1[11]);
  $poly->addPt($X+52,$yp1[12]);
  $poly->addPt($X+53,$yp1[13]);
  $poly->addPt($X+54,$yp1[14]);
  $poly->addPt($X+55,$yp1[15]);
  $poly->addPt($X+56,$yp1[16]);
  $poly->addPt($X+57,$yp1[17]);
  $poly->addPt($X+58,$yp1[18]);
  $poly->addPt($X+59,$yp1[19]);
  $poly->addPt($X+59,$yp1[20]);
  $im->filledPolygon($poly,gdStyled);

  $im->string(gdMediumBoldFont,$x0+5,$bottom,"Y",$chromColor);
}

######################################################################
sub Arrow {
  my ($im, $chrom) = @_;

  my ($ya, $yb, $yc, $yd, $ye, $yf) = split ",", $Y{$chrom};
  my $x = $X{$chrom}+30;
  $im->line($x,$ya,$x,$yb,$COLORS{black});

  my $poly = new GD::Polygon;

# Down Arrow
# $poly->addPt($x-5,$yb);
# $poly->addPt($x+5,$yb);
# $poly->addPt($x,$yb+5);

# Up Arrow
  $poly->addPt($x-5,$ya);
  $poly->addPt($x+5,$ya);
  $poly->addPt($x,$ya-5);

  $im->filledPolygon($poly,$COLORS{black});
}

######################################################################
sub TranslateBPAxis {
  my ($x0_bp, $x_bp) = @_;

  ## 'x' does NOT imply x-axis
  ## $x0_bp: origin, in SCALED base pair units, of the zoomed data area
  ## $x_bp:  position on genome in SCALED base pair units
  ## returns position as pixel

  return ($x_bp - $x0_bp);
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
sub GetFISHFromCache_1 {
  my ($base, $cache_id) = @_;

  $BASE = $base;

  return ReadFISHFromCache($cache_id);
}

######################################################################
sub ReadFISHFromCache {
  my ($cache_id) = @_;

  my ($s, @data);

  if ($cache->FindCacheFile($cache_id) eq $CACHE_FAIL) {
    return "Cache expired";
  }
  my $filename = $cache->FindCacheFile($cache_id);
  open(RIN, "$filename") or die "Can't open $filename.";
  while (read RIN, $s, 16384) {
    push @data, $s;
  }
  close (RIN);
  return join("", @data);

}

######################################################################
sub DigitalFISH_2 {

  my ($base, $org) = @_;

  my @lines;

  push @lines,
    "<CENTER>" .
    "<TABLE WIDTH=80%>" ;
  push @lines,
    "<TR>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<span style=\"color:red; background-color:red; width:1pt; height:1in;\">.</span>" .
    "<img src=\"images/fish/chromosome1.gif\">" .
    "<span style=\"color:green; background-color:green; width:1pt; height:1.5in;\">.</span>" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">1</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome2.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">2</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome3.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">3</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome4.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">4</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome5.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">5</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome6.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">6</span>" .
    "</TD>" .
    "</TR>" ;
  push @lines,
    "<TR>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome7.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">7</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome8.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">8</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome9.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">9</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome10.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">10</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome11.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">11</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome12.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">12</span>" .
    "</TD>" .
    "</TR>" ;
  push @lines,
    "<TR>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome13.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">13</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome14.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">14</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome15.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">15</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome16.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">16</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome17.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">17</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome18.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">18</span>" .
    "</TD>" .
    "</TR>" ;
  push @lines,
    "<TR>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome19.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">19</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome20.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">20</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome21.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">21</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosome22.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">22</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosomeX.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">X</span>" .
    "</TD>" .
    "<TD ALIGN=CENTER VALIGN=BOTTOM>" .
    "<img src=\"images/fish/chromosomeY.gif\">" .
    "<br><span style=\"font-family:bookman old style; color:blue; font-size:12pt; font-weight:bold\">Y</span>" .
    "</TD>" .
    "</TR>" ;
  push @lines,
    "</TABLE>" .
    "</CENTER>" ;

  return
      join("\n", @lines);
}

######################################################################
sub DigitalFISH_3 {

  my ($base, $org) = @_;

  my ($im, $image_cache_id, $imagemap_cache_id);
  my (@image_map);

  $im = InitializeImage3();

  push @image_map, "<map name=\"fishmap\">";

  DrawGrid3($im, \@image_map);

  push @image_map, "</map>";

  if (GD->require_version() > 1.19) {
    $image_cache_id = WriteFISHToCache($im->png);
  } else {
    $image_cache_id = WriteFISHToCache($im->gif);
  }

  if (! $image_cache_id) {
    return "Cache failed";
  }

  my @lines;

  push @lines,
      "<image src=\"dmhs?CACHE=$image_cache_id\" " .
      "border=0 " .
      "usemap=\"#fishmap\">";
  push @lines, @image_map;

  return
      join("\n", @lines);
}

######################################################################
sub DigitalFISH_4 {

  my ($base, $org, $karyotype) = @_;

# my $karyotype = "46,XY";
# my $karyotype = "46,XXYY";
# my $karyotype = "45,XX,-22";
# my $karyotype = "45,X,t(X;18)(p11;q11)";
# my $karyotype = "46,XY,+X,+Y";
# my $karyotype = "48,XX,+1,+2,+3,+1,+2,+3,+4,+5,+6";
# my $karyotype = "49,XX,+8,+8,+8,t(11;19)(q23;p13)";
# my $karyotype = "51,XX,+5,+7,+9,+12,+16";
# my $karyotype = "48,XX,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12";
# my $karyotype = "48,XX,+13,+14,+15,+16,+17,+18,+19,+20,+21,+22,+X,+Y";
# my $karyotype = "44,X,-1,-3,-5,-7,-11,-15,-17,-19";

  my ($im, $image_cache_id, $imagemap_cache_id);
  my (@image_map);

  $im = InitializeImage4();

  push @image_map, "<map name=\"fishmap\">";

  DrawGrid4($im, $karyotype);

  push @image_map, "</map>";

  if (GD->require_version() > 1.19) {
    $image_cache_id = WriteFISHToCache($im->png);
  } else {
    $image_cache_id = WriteFISHToCache($im->gif);
  }

  if (! $image_cache_id) {
    return "Cache failed";
  }

  my @lines;

  push @lines,
      "<image src=\"dmhs?CACHE=$image_cache_id\" " .
      "border=0 " .
      "usemap=\"#fishmap\">";
  push @lines, @image_map;

  return
      join("\n", @lines);
}


######################################################################

1;
