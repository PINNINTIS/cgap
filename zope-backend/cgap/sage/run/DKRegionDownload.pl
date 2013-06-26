#!/usr/local/bin/perl

#############################################################################
# DKRegionDownload.pl
#
 
use strict;
use CGI;
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
use DKView;
use Scan;
 
my $query                        = new CGI;
my $base                         = $query->param("BASE");
my $org                          = $query->param("ORG");
my $chr                          = $query->param("CHR");
my $mapped_data_cache_id         = $query->param("MAPPED_DATA_CACHE_ID");
my $start_pos                    = $query->param("START_POS");
my $end_pos                      = $query->param("END_POS");
my $filename                     = $query->param("FILENAME");

print "Content-type: text/plain\n\n";
 
Scan($base, $org, $chr, $mapped_data_cache_id,
     $start_pos, $end_pos, $filename);
 
print DKRegionDownload_1($base, $org, $chr, $mapped_data_cache_id,
                         $start_pos, $end_pos, $filename);
