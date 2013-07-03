#!/usr/local/bin/perl

use strict;
use FileHandle;
use CGAPConfig;
use Paging;
use DBI;
use CGI;
use Scan;

######################################################################
# GetKeggCompound.pl
#
######################################################################

my $BASE;

my %BUILDS;

######################################################################

use constant COENZYME  => 5;

## arc_types 
use constant CATALYST      => 1;
use constant SUBSTRATE_FOR => 2;
use constant PRODUCT_OF    => 3;

## return values
use constant INVALID => 2;
use constant OK      => 1;
use constant ERROR   => 0;

my (%enzymes, %compounds, %coords, %from_type, %to_type);
my (%node_id, %node_type, %node_name, %node_link, $orig_node);
my (%arc_id, %arc_type, %arc_src, %arc_dest, %arc_path, %path_name);
my (@possible_path, @possible_paths, @Queried, $depth, $dest_path);

my $query     = new CGI;
my $base      = $query->param("BASE");
my $cno       = $query->param("CNO");

print "Content-type: text/plain\n\n";
 
Scan($base, $cno);
## print GetyKeggCompound($base, $cno);
print GetKeggCompound($base, $cno);

sub numerically   { $a <=> $b; }

######################################################################
sub GetKeggCompound {

  my ($base, $cno) = @_;

  $BASE = $base;

  my (@rows, $row, $graphic);
  my ($path_id, $pathway_name);
  my ($name, $coords);
  my ($locus_id, $c1, $c2, $c3, $c4);

  if ($cno ne '') {
    my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);

    if (not $db or $db->err()) {
      ##print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print STDERR "Cannot connect to database \n";
      return "";
    }

 
    my $sql = "select * from $CGAP_SCHEMA.KeggCoords ";
   
    my $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</certer>";
      $db->disconnect();
      return "";
    }
   
    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       $db->disconnect();
       return "";
    }
   
    $stm->bind_columns(\$path_id, \$locus_id, \$c1, \$c2, \$c3, \$c4);
    while ($stm->fetch) {
      if (defined $coords{$path_id}{$locus_id}) {
        $coords{$path_id}{$locus_id} .= ';' . "$c1,$c2,$c3,$c4";
      } else {
        $coords{$path_id}{$locus_id}  = "$c1,$c2,$c3,$c4";
      }
    }
 


    my $dqcno = $cno;
    $dqcno =~ s/'/''/g;
    my $sql = "select distinct name " .
              "from $CGAP_SCHEMA.KeggCompounds " .
              "where cno = '$dqcno' ";
    my $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</certer>";
      $db->disconnect();
      return "";
    }

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       $db->disconnect();
       return undef;
    }

    push @rows, "<table border=0 width=100%>" .
      "<tr bgcolor=\"#666699\">" .
      "<td align=center colspan=4><font color=\"white\"><b>Compound $cno Names</b></font></td></tr>" .
      "<tr><td>&nbsp;</td></tr>" ;

    $stm->bind_columns(\$name);
    push @rows, "<tr><td width=8%>&nbsp;</td><td class=\"keggpath\">";
    while ($stm->fetch) {
      $row = "$name<br>";
      push @rows, $row;
    }
    push @rows, "</td></tr></table><br>";
    $stm->finish;

    my $sql_pathway = "select distinct p.path_id, p.pathway_name " .
                      "from $CGAP_SCHEMA.KeggComponents k, " .
                      "$CGAP_SCHEMA.KeggPathNames p " .
                      "where k.path_id = p.path_id " .
                      "and k.ecno = upper('$dqcno') " .
                      "order by p.pathway_name";

    my $stm = $db->prepare($sql_pathway);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</certer>";
      $db->disconnect();
      return "";
    }

    if (!$stm->execute()) {
       ## print STDERR "$sql_pathway\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       $db->disconnect();
       return undef;
    }

    $stm->bind_columns(\$path_id, \$pathway_name);

    push @rows,
      "<table border=0 width=100%>" .
      "<tr bgcolor=\"#666699\">" .
      "<td align=center colspan=4><font color=\"white\"><b>Pathways involving Compound $cno</b></font></td></tr>" .
      "<tr><td>&nbsp;</td></tr>" ;

    my $pcnt = 0;
    while ($stm->fetch) {
      if ($coords{$path_id}{$cno}) {
        $coords = join(",", split("\t",$coords{$path_id}{$cno}));
      }
      if ($pathway_name) {
        $row = "<tr><td width=8%><img src=\"" . IMG_DIR . "/Kegg/bullet.gif\" height=10 width=10 align=right border=0></td><td><a class=\"genesrch\" href=javascript:ColoredPath(\"$BASE/Pathways/Kegg/$path_id\",\"$coords\",\"$cno\")>$pathway_name</a></td></tr>";
        push @rows, $row;
        $pcnt++;
      }
    }
    $stm->finish;
    $db->disconnect();

    if ($pcnt == 0) {
      push @rows, "<tr><td class=\"keggpath\">No Pathways Found</td></tr>";
    }
    push @rows, "</table><br>";

    push @rows,
      "<table border=0 width=100%>" .
      "<tr bgcolor=\"#666699\">" .
      "<td align=center><font color=\"white\"><b>Compound Structure</b></font></td></tr>" .
      "<tr><td>&nbsp;</td></tr>" ;
    push @rows, "<tr><td align=center><img src=\"" . KEGG_DIR . "/Compounds/$cno\.gif\" align=center border=0></td></tr></table>";

  }
  else {
    push @rows, "<table><tr><td class=\"keggpath\">No Compound Found</td></tr></table>";
  }

  return join "\n", @rows;
}

######################################################################
