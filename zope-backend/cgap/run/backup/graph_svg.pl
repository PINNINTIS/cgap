#!/usr/local/bin/perl

use strict;
use GD;
use SVG;

my $SVG_IMAGE_HEIGHT = 1000;
my $SVG_IMAGE_WIDTH  = 600;
my $SCREEN_HEIGHT = 1000;
my $SCREEN_WIDTH  = 600;
my %scale2color;
my ($white, $black, $red, $blue, $green, $yellow);

## print "Content-type: image/gif\n\n";
print "Content-type: text/plain\n\n";

my $svg = SVG->new(width=>$SVG_IMAGE_WIDTH,height=>$SVG_IMAGE_HEIGHT);
InitializeSVGColor(\%scale2color, \$white, \$black,
                   \$red, \$blue, \$green, \$yellow);
my $str = "This is test SVG";
my $x1 = 20;
my $y1 = 30;
$svg->text(x=>$x1,y=>$y1,style=>{'font-size'=>12, 'font-weight'=>'bold', 'fill'=>$black},)->cdata($str);

$svg->rect(x=>$x1+20,y=>$y1+60,width=>40, height=>60,style=>{fill=>$red});
my $out = $svg->xmlify;

my $filename = "/cgap/schaefec/test_cgi/SVG.test";
if (open(OUT, ">$filename")) {
  print OUT $out;
  close OUT;
  chmod 0666, $filename;
}
else {
  print "Can not open file $filename\n";
}
print  "SVG Test<br>";
my @lines;
push @lines, "<form name=mform method=post>";
push @lines,
      "<EMBED src=\"GetImage_SVG\" " .
      "NAME=\"SVGEmbed\" " .
      "HEIGHT=\"$SCREEN_HEIGHT\" WIDTH=\"$SCREEN_WIDTH\" " .
      "TYPE=\"image/svg-xml\" " .
      "PLUGINPAGE=\"http://www.adobe.com/svg/viewer/install/\">";
push @lines, "</form>";
print join("", @lines) . "<br>";
print  "SVG Test is done<br>";

######################################################################
sub InitializeSVGColor {
  my ($scale2color,
      $white,
      $black,
      $red,
      $blue,
      $green,
      $yellow) = @_;
 
  $$white       = "rgb(255,255,255)";
  $$black       = "rgb(0,0,0)";
  $$red         = "rgb(255,0,0)";
  $$blue        = "rgb(0,0,255)";
  $$green       = "rgb(0,128,0)";
  $$yellow      = "rgb(255,255,0)";
 
  my $color1  = "rgb(0,0,255)";
  my $color2  = "rgb(51,153,255)";
  my $color3  = "rgb(102,204,255)";
  my $color4  = "rgb(153,204,255)";
  my $color5  = "rgb(204,204,255)";
  my $color6  = "rgb(255,204,255)";
  my $color7  = "rgb(255,153,255)";
  my $color8  = "rgb(255,102,204)";
  my $color9  = "rgb(255,102,102)";
  my $color10 = "rgb(255,0,0)";
  my $color11 = "rgb(0,0,0)";
 
  $$scale2color{'0000FF'} = $color1;
  $$scale2color{'3399FF'} = $color2;
  $$scale2color{'66CCFF'} = $color3;
  $$scale2color{'99CCFF'} = $color4;
  $$scale2color{'CCCCFF'} = $color5;
  $$scale2color{'FFCCFF'} = $color6;
  $$scale2color{'FF99FF'} = $color7;
  $$scale2color{'FF66CC'} = $color8;
  $$scale2color{'FF6666'} = $color9;
  $$scale2color{'FF0000'} = $color10;
  $$scale2color{'000000'} = $color11;
}

