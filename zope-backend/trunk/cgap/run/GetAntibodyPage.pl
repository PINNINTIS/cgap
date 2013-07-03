#!/usr/local/bin/perl

#############################################################################
# GetAntibodyPage.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use Antibody;
use Scan;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $id        = $query->param("ID");
my $name      = $query->param("NAME");
my $catalog   = $query->param("CATALOG");
my $supplier  = $query->param("SUPPL");
my $host      = $query->param("HOST");

print "Content-type: text/plain\n\n";

## print "$name, $gene, $mod, $catalog, $supplier\n";
Scan($base, $id, $name, $catalog, 
     $supplier, $host);
print GetAntibodyPage_1($base, $id, $name, $catalog, 
                        $supplier, $host);
