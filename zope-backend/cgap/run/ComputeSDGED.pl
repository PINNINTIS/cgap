#!/usr/local/bin/perl

######################################################################
# ComputeSDGED.pl
#
# 
# 


BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use strict;
use FileHandle;
use CGAPConfig;
use Scan;
use GXS;

my $TIME_LIMIT = 60;
my $RUN_TIME = 30;

my ( $base, $cache_id, $org, $page, $factor, $pvalue, $chr, $user_email,
     $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
     $setA, $setB, $method, $sdged_cache_id, $email);

my $dir = CACHE_ROOT;
my @tmp_files;
my ($sec, $min, $hr, $mday, $mon, $year, $wday, $yday, $isdst) =
      localtime(time);

my $process_count_1 = 0;
my $process_count_2 = 0;

opendir (DATADIR, $dir) or die "Can not open $dir \n";
while( my $file = readdir(DATADIR) ) {
  if( !($file =~ /^\./) ) {
    if( ($file =~ /^GXS/) ) {
      if( $file =~ /\.tmp.copy$/ ) {
        $process_count_1++;
        my $filename = $dir . $file;
        my $t = (stat "$filename")[9];
        my ($f_sec, $f_min, $f_hr, $f_mday, $f_mon, $f_year, $f_wday, $f_yday, $f_isdst) = localtime($t);
        if( $year == $f_year ) {
          if( $yday == $f_yday ) {
            if( $hr*60 + $min >= $f_hr*60 + $f_min + $TIME_LIMIT ) {
              $process_count_1--;
              my $file_copy_old = $filename . ".old";
              if(rename $filename, $file_copy_old) {
                push @tmp_files, $file_copy_old;
              }

              ##  $filename;
              my $bak_file = $dir . "bak_" . $file . "_bak";
              my $cmd = "cp $file_copy_old $bak_file";
              system($cmd);
            }
            else {
              next;
            }
          }
          elsif( $yday == $f_yday + 1 ) {
            $process_count_1--;
            my $file_copy_old = $filename . ".old";
            if(rename $filename, $file_copy_old) {
              push @tmp_files, $file_copy_old;
            }
 
            ##  $filename;
            my $bak_file = $dir . "bak_" . $file . "_bak";
            my $cmd = "cp $file_copy_old $bak_file";
            system($cmd);
          }
        }
      }
      elsif( $file =~ /\.tmp.copy.old$/ ) {
        $process_count_2++;
        my $filename = $dir . "bak_" . $file . "_bak";
        if( -e $filename ) {
          my $t = (stat "$filename")[9];
          my ($f_sec, $f_min, $f_hr, $f_mday, $f_mon, $f_year, $f_wday, $f_yday, $f_isdst) = localtime($t);
          if( $hr*60 + $min < $f_hr*60 + $f_min + $RUN_TIME ) {
            $process_count_2--;
          }
        }
        else {
          my $filename = $dir . $file;
          my $t = (stat "$filename")[9];
          my ($f_sec, $f_min, $f_hr, $f_mday, $f_mon, $f_year, $f_wday, $f_yday, $f_isdst) = localtime($t);
          if( $hr*60 + $min >= $f_hr*60 + $f_min + $TIME_LIMIT + $RUN_TIME ) {
            $process_count_2--;
          }
        } 
      }
    }
  }
}
closedir DATADIR;

if( $process_count_1 > 0  or $process_count_2 > 0) {
  exit();
} 

opendir (DATADIR, $dir) or die "Can not open $dir \n";
while( my $file = readdir(DATADIR) ) {
  if( !($file =~ /^\./) ) {
    if( ($file =~ /^GXS/) ) {
      if( $file =~ /\.tmp$/ ) {
        my $filename = $dir . $file;
        my $file_copy = $filename . ".copy";
        if(rename $filename, $file_copy) {
          push @tmp_files, $file_copy;
        }
      }
    }
  }
}
closedir DATADIR;

for( my $i=0; $i<@tmp_files; $i++ ) {
  if ( -e $tmp_files[$i] ) {
    my @INPFS;
    open( TMP_FN, $tmp_files[$i] )  or die "Cannot open $tmp_files[$i]\n";
    while(<TMP_FN>) {
      chop;
      push @INPFS, $_;
    }
    
    $base              = $INPFS[0];
    $cache_id          = $INPFS[1];
    $org               = $INPFS[2];
    $page              = $INPFS[3];
    $factor            = $INPFS[4];
    $pvalue            = $INPFS[5];
    $chr               = $INPFS[6];
    $user_email        = $INPFS[7];
    $total_seqsA       = $INPFS[8];
    $total_seqsB       = $INPFS[9];
    $total_libsA       = $INPFS[10];
    $total_libsB       = $INPFS[11];
    $setA              = $INPFS[12];
    $setB              = $INPFS[13];
    $method            = $INPFS[14];
    $sdged_cache_id    = $INPFS[15];
    $email             = $INPFS[16];
  
    close INPF;
    ComputeSDGED_1 
        ($base, $cache_id, $org, $page, $factor, $pvalue, $chr, $user_email,
         $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
         $setA, $setB, $method, $sdged_cache_id, $email);
    unlink $tmp_files[$i];
  } 
}
