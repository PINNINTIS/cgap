#!/usr/local/bin/perl

######################################################################
# PrepareSDGED.pl
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
use CGI;
 
my $query     = new CGI;
 
my $base      = $query->param("base");
my $fn        = $query->param("FILE");
 
print "Content-type: text/plain\n\n";

Scan($fn);

my (
      $base, $cache_id, $org, $page, $factor, $pvalue, $chr, $user_email,
      $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
      $setA, $setB, $method, $sdged_cache_id, $email);

open (INPF, $fn) or die "Cannot open $fn";

$base              = <INPF>; chop $base;
$cache_id          = <INPF>; chop $cache_id;
$org               = <INPF>; chop $org;
$page              = <INPF>; chop $page;
$factor            = <INPF>; chop $factor;
$pvalue            = <INPF>; chop $pvalue;
$chr               = <INPF>; chop $chr;
$user_email        = <INPF>; chop $user_email;
$total_seqsA       = <INPF>; chop $total_seqsA;
$total_seqsB       = <INPF>; chop $total_seqsB;
$total_libsA       = <INPF>; chop $total_libsA;
$total_libsB       = <INPF>; chop $total_libsB;
$setA              = <INPF>; chop $setA;
$setB              = <INPF>; chop $setB;
$method            = <INPF>; chop $method;
$sdged_cache_id    = <INPF>; chop $sdged_cache_id;
$email             = <INPF>; chop $email;

close INPF;

if ( $user_email eq "" ) { 
  print "<center><b>Please fill the email address.</b></center>";
  unlink CACHE_ROOT . GXS_CACHE_PREFIX . ".$email";
  exit();
}
elsif( $user_email =~ /^\@/ or !($user_email =~ /\@/) ) {
  print "<center><b>Please fill a correct email address.</b></center>";
  unlink CACHE_ROOT . GXS_CACHE_PREFIX . ".$email";
  exit();
}

my $tmp_file = CACHE_ROOT . GXS_CACHE_PREFIX . ".$email.tmp"; 
open(OUT, ">$tmp_file") or die "Cannot open file $tmp_file\n";
print OUT $base              . "\n";
print OUT $cache_id          . "\n";
print OUT $org               . "\n";
print OUT $page              . "\n";
print OUT $factor            . "\n";
print OUT $pvalue            . "\n";
print OUT $chr               . "\n";
print OUT $user_email        . "\n";
print OUT $total_seqsA       . "\n";
print OUT $total_seqsB       . "\n";
print OUT $total_libsA       . "\n";
print OUT $total_libsB       . "\n";
print OUT $setA              . "\n";
print OUT $setB              . "\n";
print OUT $method            . "\n";
print OUT $sdged_cache_id    . "\n";
print OUT $email             . "\n";
close OUT;
chmod 0666, $tmp_file;

unlink $fn;

print Info_Return( $cache_id, $org, $page, $factor, $pvalue, $chr, $user_email,
                   $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
                   $setA, $setB, $method, $sdged_cache_id, $email );

sub Info_Return {
 
  my ($cache_id, $org, $page, $factor, $pvalue, $chr, $user_email,
      $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
      $setA, $setB, $method, $sdged_cache_id, $email) =@_;

  my $start_time = time();
  my @month_abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
  my @week_abbr = qw( Sun Mon Tues Wed Thurs Fri Sat );
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                        localtime($start_time);
  my $y = $year + 1900;
  $sec = sprintf("%02d", $sec);
  $min = sprintf("%02d", $min);
  $hour = sprintf("%02d", $hour);
  my $current_time = "$week_abbr[$wday] $month_abbr[$mon] $mday $hour:$min:$sec $y";
  my $output =
        "<html>" .
        "<head>" .
        "<script>" .
        "function trylink() {" .
        "window.location=\"/SAGE/GetUserResult?CACHE=$email&TIME=$start_time&EMAIL=$user_email\";".
        "}" .
        "function delay() {" .
        "setTimeout(\"trylink()\", 30000);" .
        "}" .
        "</script>" .
        "</head>" .
        "<body onLoad=\"delay()\">" .
        "<BR><BR>" .
        "<center><table>" .
        "<tr><td valign=top>Request ID</td><td valign=top>$email</td><tr>" .
        "<tr><td valign=top>Submitted at&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td valign=top>$current_time</td></tr>" .
        "</table></center><br><br>" .
        ## "<BR><BR><center><a href=/SAGE/GetUserResult?CACHE=$email&TIME=$start_time>Please wait several minutes and then click the hyper link here</a></center><br><br>" .        
        ## "<center>This page will be automatically updated in 30 seconds.</center>" .
        "<center>When the results are ready, they will appear in this window.</center>" .
        "<center>Or you can close this window; the link for the results will be emailed to $user_email.</center>" .
        "</body>";
  return $output;
}

