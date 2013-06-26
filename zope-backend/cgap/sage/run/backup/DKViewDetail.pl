#!/usr/local/bin/perl

#############################################################################
# DKViewDetail.pl
#
 
use strict;
use CGI;
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
use DKView;
 
my $query                = new CGI;
my $base                 = $query->param("BASE");
my $org                  = $query->param("ORG");
my $chr                  = $query->param("CHR");
my $pos                  = $query->param("POS");
my $start_pos            = $query->param("START_POS");
my $end_pos              = $query->param("END_POS");
my $window_size          = $query->param("WINDOWSIZE");
my $filename             = $query->param("FILENAME");
my $mapped_data_cache_id = $query->param("MAPPED_DATA_CACHE_ID");
my $DEL_WIDTH            = $query->param("DELWIDTH");
my $DEL_THRESHHOLD       = $query->param("DELTHRESHHOLD");
my $AMP_WIDTH            = $query->param("AMPWIDTH");
my $AMP_THRESHHOLD       = $query->param("AMPTHRESHHOLD");
my $start_num            = $query->param("START_NUM");
my $end_num              = $query->param("END_NUM");
 
print "Content-type: text/plain\n\n";

print DKViewDetail_1($base, $org, $chr, $pos, $start_pos, $end_pos, 
                     $window_size, $filename, $mapped_data_cache_id,
                     $DEL_WIDTH, $DEL_THRESHHOLD, 
                     $AMP_WIDTH, $AMP_THRESHHOLD,
                     $start_num, $end_num);
