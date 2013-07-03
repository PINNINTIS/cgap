#!/usr/local/bin/perl

use strict;
use lib '../lib';
## use GraphViz::Data::Grapher;
use GraphViz;
use SVG;

my $SVG_IMAGE_HEIGHT = 1000;
my $SVG_IMAGE_WIDTH  = 600;
my $SCREEN_HEIGHT = 1000;
my $SCREEN_WIDTH  = 600;
my %scale2color;
my ($white, $black, $red, $blue, $green, $yellow);


## print "Content-type: image/gif\n\n";
print "Content-type: text/plain\n\n";

my $g = GraphViz->new();

$g->add_node('London', label => ['Heathrow', 'Gatwick']);
$g->add_node('Paris', label => 'CDG');
$g->add_node('New York', label => 'JFK');

$g->add_edge('London' => 'Paris', from_port => 0);

$g->add_edge('New York' => 'London', to_port => 1);

## $g->as_png("/cgap/schaefec/test_cgi/port.png");
## $g->as_png("port.png");
## $g->as_fig("/cgap/schaefec/test_cgi/port.fig");
$g->as_svg("/cgap/schaefec/test_cgi/port.svg");
## $g->as_svg("port.svg");
## print $g->as_svg;
my $filename = "/cgap/schaefec/test_cgi/port.svg";
## if (open(OUT, ">$filename")) {
##   print OUT $g->as_svg;
## }
## else {
##   print "OUT_ORDER<br>";
## } 
## my $filename = "/cgap/schaefec/test_cgi/port.svg";
## if (open(OUT, ">$filename")) {
##   print OUT $out;
##   close OUT;
##   chmod 0666, $filename;
## }
## else {
##   print "Can not open file $filename\n";
## }

my $cmd = "chmod 666 /cgap/schaefec/test_cgi/port.svg";
system($cmd);

print  "GRAPHVIZ Test<br>";
my @lines;
## push @lines, "<form name=mform method=post>";
## push @lines,
##       "<EMBED src=\"GetImage_GRAPHVIZ\" " .
##       "NAME=\"SVGEmbed\" " .
##       "HEIGHT=\"$SCREEN_HEIGHT\" WIDTH=\"$SCREEN_WIDTH\" " .
##       "TYPE=\"image/svg-xml\" " .
##       "PLUGINPAGE=\"http://www.adobe.com/svg/viewer/install/\">";
## push @lines, "</form>";
## print join("", @lines) . "<br>";
print  "GRAPHVIZ Test is done<br>";

 

