#!/usr/local/bin/perl

#############################################################################
# GetStat.pl
#

use strict;
use CGI;
use Scan;

## my $sage_grop_raw = "/cgap/webcontent/CGAP/dev/data/sage_group.raw";
## my $sage_raw = "/cgap/webcontent/CGAP/dev/data/sage.raw";
## my $sage_stat = "/cgap/webcontent/CGAP/dev/data/sage_zero_stat.txt";
my $sage_grop_raw = "/cgap/schaefec/current/SAGE/data/sage_group.raw";
my $sage_raw = "/cgap/schaefec/current/SAGE/data/sage.raw";
my $sage_stat = "/cgap/schaefec/current/SAGE/data/sage_zero_stat.txt";

open( SAGE_GROUP_IN, $sage_grop_raw);
open( SAGE_IN, $sage_raw);
open( SAGE_OUT, ">$sage_stat");


my $count = 0;
my $count_20 = 0;
my $count_40 = 0;
my $count_60 = 0;
my $count_80 = 0;
my $count_100 = 0;

while( <SAGE_GROUP_IN> ) {
  chop;
  if( $count > 0 ) {
    my @tmp = split "\t", $_;
    my $total = @tmp - 2;
    my $num = 0;
    for(my $i=1; $i<@tmp; $i++) {
      ## print "$tmp[$i] \n";
      if($tmp[$i] == 0) {
        $num++;
      }  
    } 
    my $ratio = $num/$total * 100;;
    ## print "R: $ratio \n";
    if( $ratio <=20 ) {
      $count_20++; 
    }
    elsif( $ratio <=40 ) {
      $count_40++; 
    }
    elsif( $ratio <=60 ) {
      $count_60++; 
    }
    elsif( $ratio <=80 ) {
      $count_80++; 
    }
    elsif( $ratio <=100 ) {
      $count_100++; 
    }
  }
  $count++;
}

$count = $count - 1;
print SAGE_OUT "SAGE_GROUP: \n"; 
print SAGE_OUT "total: $count \n"; 
my $ratio = $count_20/$count*100;
print SAGE_OUT "total 20%: $count_20 and $ratio%\n"; 
my $ratio = $count_40/$count*100;
print SAGE_OUT "total 40%: $count_40 and $ratio%\n"; 
my $ratio = $count_60/$count*100;
print SAGE_OUT "total 60%: $count_60 and $ratio%\n"; 
my $ratio = $count_80/$count*100;
print SAGE_OUT "total 80%: $count_80 and $ratio%\n"; 
my $ratio = $count_100/$count*100;
print SAGE_OUT "total 100%: $count_100 and $ratio%\n"; 

my $count = 0;
my $count_20 = 0;
my $count_40 = 0;
my $count_60 = 0;
my $count_80 = 0;
my $count_100 = 0;

while( <SAGE_IN> ) {
  chop;
  if( $count > 0 ) {
    my @tmp = split "\t", $_;
    my $total = @tmp - 2;
    my $num = 0;
    for(my $i=1; $i<@tmp; $i++) {
      if($tmp[$i] == 0) {
        $num++;
      }  
    } 
    my $ratio = $num/$total * 100;;
    if( $ratio <=20 ) {
      $count_20++; 
    }
    elsif( $ratio <=40 ) {
      $count_40++; 
    }
    elsif( $ratio <=60 ) {
      $count_60++; 
    }
    elsif( $ratio <=80 ) {
      $count_80++; 
    }
    elsif( $ratio <=100 ) {
      $count_100++; 
    }
  }
  $count++;
}

$count = $count - 1;
print SAGE_OUT "SAGE: \n"; 
print SAGE_OUT "total: $count \n"; 
my $ratio = $count_20/$count*100;
print SAGE_OUT "total 20%: $count_20 and $ratio%\n"; 
my $ratio = $count_40/$count*100;
print SAGE_OUT "total 40%: $count_40 and $ratio%\n"; 
my $ratio = $count_60/$count*100;
print SAGE_OUT "total 60%: $count_60 and $ratio%\n"; 
my $ratio = $count_80/$count*100;
print SAGE_OUT "total 80%: $count_80 and $ratio%\n"; 
my $ratio = $count_100/$count*100;
print SAGE_OUT "total 100%: $count_100 and $ratio%\n"; 

