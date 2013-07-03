#!/usr/local/bin/perl

BEGIN {

  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);

}
######################################################################

use strict;
## use cor;
use Bayesian;
use GetPvalueForT;
use CGI;


print "Content-type: text/plain\n\n";


print "I am here";
