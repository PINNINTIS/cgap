#!/usr/local/bin/perl

use strict;
use DBI;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

if (-d "/app/oracle/product/dbhome/current") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/dbhome/current";
} elsif (-d "/app/oracle/product/8.1.7") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.7";
} elsif (-d "/app/oracle/product/8.1.6") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.6";
} elsif (-d "/app/oracle/product/10gClient") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/10gClient"
}

my (
  $db_inst,
  $db_user,
  $db_pass,
  $schema
) = ("cgprod", "web", "readonly", "cgap2");

use constant MAX_ROWS_PER_FETCH => 1000;

my $protocol = "A";
my $experiment_name  = "SAGE";
my $organism = "Hs";
my @lines;

my $db = DBI->connect("DBI:Oracle:" . $db_inst, $db_user, $db_pass);
if (not $db or $db->err()) {
  print STDERR "Cannot connect to " . $db_user . "@" . $db_inst . "\n";
  exit();
}

print "Content-type: text/plain\n\n";

push @lines, qq!
<html>
<head>
<title>Correlates</title>
<style TYPE="text/css">
BODY {background-color: #ffffff; font-family: Arial, Helvetica, sans-serif; font-size:10pt;}
  UL,OL,TH,TD,P,DD,DT,DL,BLOCKQOUTE,H1,H2,H3,H4,H5,H6
      {font-family: Arial, Helvetica, sans-serif; font-size:10pt; color:#336699}
</STYLE>
</head>
<body>
<h3>JHMI Query</h3>
<blockquote>
Find positive, negative correlates of a shorthuman SAGE tag in a specified
set of short human SAGE libraries.
!;

CreateList($db);
$db->disconnect();

push @lines, qq!
</blockquote>
</body>
!;

print join("\n", @lines) . "\n";

######################################################################
sub LIB_URL {
  my ($id) = @_;

  return "http://cgap.nci.nih.gov/SAGE/SAGELibInfo?LID=$id&ORG=$organism";
}

######################################################################
sub CreateList {
  my ($db) = @_;

  my ($sql, $stm);
  my ($col_order, $panel_name, $name, $sage_library_id);
  my ($last_panel_name);

  $sql = "select b.col_order, b.panel_name, n.name, n.sage_library_id " .
      "from $schema.cgap_2d_bioassay b, $schema.sagelibnames n, " .
      "$schema.cgap_2d_experiment e " .
      "where n.nametype = 'DUKE' " .
      "and b.bioassay_name = n.name " .
      "and b.bioassay_experiment_id = e.experiment_id " .
      "and e.experiment_name = '$experiment_name' " .
      "and e.organism = '$organism'";
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print STDERR "prepare call failed\n";
    $db->disconnect();
    exit;
  }
  if (! $stm->execute()) {
    print STDERR "execute call failed\n";
    $db->disconnect();
    exit;
  }

  push @lines, "<form action=\"Subset2DSearch.pl\" method=POST>";
  
  push @lines, "<table>";
  push @lines, "<tr><td>Tag</td><td><input type=text name=TAG></td></tr>";
  push @lines, "</table>";

  push @lines, "<table>";
  push @lines, "<tr><td><input type=submit></td>" .
      "<td><input type=reset></td></tr>";
  push @lines, "</table>";

  push @lines, "<table>";
  my ($row, $rowcache);
  while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
    for $row (@{ $rowcache }) {
      ($col_order, $panel_name, $name, $sage_library_id) = @{ $row };
      push @lines, "<tr>";
      if ($panel_name ne $last_panel_name) {
        push @lines, "<td>$panel_name</td>";
      } else {
        push @lines, "<td>&nbsp;</td>";
      }
      $last_panel_name = $panel_name;
      push @lines, "  <td><input type=checkbox name=C_$col_order></td>";
      push @lines, "  <td>[$col_order] <a href=\"" .
          LIB_URL($sage_library_id) . "\">$name</td>";
      push @lines, "</tr>";
    }
  }
  push @lines, "</table>";
  push @lines, "</form>";
}
