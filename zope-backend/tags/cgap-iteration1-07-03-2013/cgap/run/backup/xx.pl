#!/usr/local/bin/perl
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
 
use strict;
use CGI;
use CGAPConfig;
## use GetPvalueForT;
## use cor;
## use Bayesian;
 
print "Content-type: text/plain\n\n";
print join("\n", @INC) . "\n";
print "end";
exit;
