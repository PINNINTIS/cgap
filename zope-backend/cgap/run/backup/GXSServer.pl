#!/usr/local/bin/perl

use strict;
use FileHandle;
use CGAPConfig;
#use Paging;
use ServerSupport;
use GXS;

######################################################################
# GXSServer.pl
#
#
######################################################################

sub ComputeGXS {
  return ComputeGXS_1 (@_);
}

sub ComputeSDGED {
  return ComputeSDGED_1 (@_);
}

sub MoveUploadFileToLocal {
  return MoveUploadFileToLocal_1 (@_);
}

sub ComputeSDGED_Async {
  ComputeSDGED_1 (@_);
}

sub Info_Return {

  my ($cache_id, $org, $page, $factor, $pvalue, $chr,
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
        "window.location=\"/SAGE/GetUserResult?CACHE=$email&TIME=$start_time\";".
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
        "</table></center>" .
        "<BR><BR><center><a href=/SAGE/GetUserResult?CACHE=$email&TIME=$start_time>Please wait several minutes and then click the hyper link here</a></center><br><br>" .
        " <center>This page will be automatically updated in 30 seconds.</center>" .
        ## " <center>This window will be automatically updated when the results of your query are ready.</center>" .
        "</body>";
  return $output; 

  ## return "<BR><BR><center><a href=http://cgap-stage.nci.nih.gov/SAGE/GetUserResult?CACHE=$email&TIME=$start_time>Please wait 5 minutes and then click the hyper link here</a></center>";
}

######################################################################
# main
#
######################################################################

SetProgramName($0);

SetSafe(
  "ResetServer",
  "ComputeGXS",
  "ComputeSDGED",
  "MoveUploadFileToLocal",
  "Info_Return"
);

SetForkable(
  "ComputeGXS",
  "ComputeSDGED",
  "MoveUploadFileToLocal"
);

SetAsync("Info_Return", "ComputeSDGED_Async");

StartServer(GXS_SERVER_PORT, "GXSServer");

#print ComputeSDGED(0,1,"Hs",2,.05,0,0,0,0,"14,13","11,12");
#exit;

######################################################################

