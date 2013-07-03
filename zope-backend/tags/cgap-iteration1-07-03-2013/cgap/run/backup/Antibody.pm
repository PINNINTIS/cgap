#!/usr/local/bin/perl

######################################################################
# Antibody.pm
#
######################################################################

use strict;
use DBI;
use CGAPConfig;

my $BASE;

my %aa_map = (
  "A" => "Ala",
  "R" => "Arg",
  "N" => "Asn",
  "D" => "Asp",
  "C" => "Cys",
  "Q" => "Gln",
  "E" => "Glu",
  "G" => "Gly",
  "H" => "His",
  "I" => "Ile",
  "L" => "Leu",
  "K" => "Lys",
  "M" => "Met",
  "F" => "Phe",
  "P" => "Pro",
  "S" => "Ser",
  "T" => "Thr",
  "W" => "Trp",
  "Y" => "Tyr",
  "V" => "Val"
);


if (-d "/app/oracle/product/8.1.7") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.7";
} else {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.6";
}

######################################################################
sub numerically { $a <=> $b ;}

######################################################################
sub r_numerically { $b <=> $a; }

######################################################################
sub DividerBar {
  my ($title) = @_;
  return "<table width=95% cellpadding=2>" .
      "<tr bgcolor=\"#666699\"><td align=center>" .
      "<font color=\"white\"><b>$title</b></font>" .
      "</td></tr></table>\n";
}

######################################################################
sub GetAntibodyList_1 {
  my ($base) = @_;
  my @lines;

  my %all_ab_info;

  my $antibody_line;

  $BASE = $base;

  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    $db = "";
  }

  getAntibodyInfo($db, \%all_ab_info);

  my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#666699\">" .
      "<td><font color=\"white\"><b>Symbol</b></font></td>" .
      "<td><font color=\"white\"><b>Modifications</b></font></td>" .
      "<td><font color=\"white\"><b>Antibody Name</b></font></td>" .
      "<td><font color=\"white\"><b>Host</b></font></td>" .
      "<td><font color=\"white\"><b>Catalog</b></font></td>" .
      "<td><font color=\"white\"><b>Supplier Abbreviation</b></font></td>" .
      "</tr>\n";

  my $antibody_line = $table_header;

  for my $gene ( sort keys %all_ab_info ) {
    for my $ab_name ( sort keys %{$all_ab_info{$gene}} ) {
      for my $host ( sort keys %{$all_ab_info{$gene}{$ab_name}} ) {
        for my $catalog ( sort keys %{$all_ab_info{$gene}{$ab_name}{$host}} ) {
          for my $suppl ( sort keys %{$all_ab_info{$gene}{$ab_name}{$host}{$catalog}} ) {

            my $modi;
            my $id;
            my $count = 0;
            for my $mod_site1 ( sort numerically keys %{$all_ab_info{$gene}{$ab_name}{$host}{$catalog}{$suppl}} ) {
              for my $aa ( sort keys %{$all_ab_info{$gene}{$ab_name}{$host}{$catalog}{$suppl}{$mod_site1}} ) {
                if( $count == 0 ) {
                  $modi = $aa_map{$aa} . $mod_site1; 
                }
                else { 
                  $modi = $modi . "<br>" . $aa_map{$aa} . $mod_site1; 
                }
                $count++;
                $id = $all_ab_info{$gene}{$ab_name}{$host}{$catalog}{$suppl}{$mod_site1}{$aa};
              }
            }

            my @temp = split "\t", $gene;
            my $gene_info = 
              "<a href=CGAP/Genes/GeneInfo?ORG=Hs&CID=$temp[1]>$temp[0]</a>";
            my $url_name = convrt($ab_name);
            my $catalog_name = convrt($catalog);
            my @tmp = split "\t", $suppl;
            my $sup = "<a href=javascript:spawn(\"$tmp[1]\")>$tmp[0]</a>";
            my $name = 
               "<a href=\"AntibodyPage?ID=$id&NAME=$url_name&CATALOG=$catalog_name&SUPPL=$tmp[0]&HOST=$host\">$ab_name</a>";
            $antibody_line = $antibody_line .
               "<tr>" .
                  "<td valign=bottom>$gene_info</td>" .
                  "<td valign=bottom>$modi</td>" .
                  "<td valign=bottom>$name</td>" .
                  "<td valign=bottom>$host</td>" .
                  "<td valign=bottom>$catalog</td>" .
                  "<td valign=bottom>$sup</td>" .
               "</tr>";
          }
        }
      }
    }   
  }
 
  $antibody_line = $antibody_line . "</table>";
 
  my @lines;

  push @lines, $antibody_line;

  return join("\n", @lines);

}

######################################################################
sub GetAntibodyPage_1 {
  my ($base, $id, $name, $catalog, $supplier_abbrev, $host) = @_;
  my @lines;

  my %all_ab_info;
  my %some_ab_info;

  my $antibody_line;

  $BASE = $base;

  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    $db = "";
  }

  my ($description, $supplier_name, $supplier_url, $curator)
         = getSomeAntibodyInfo($db, $id, $supplier_abbrev, \%some_ab_info);

  my $sup_info = 
       "<a href=javascript:spawn(\"$supplier_url\")>$supplier_name</a>";

  my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#666699\">" .
      "<td><font color=\"white\"><b>Symbol</b></font></td>" .
      "<td><font color=\"white\"><b>Modifications</b></font></td>" .
      "</tr>\n";

  my $antibody_line = $table_header;

  for my $gene ( sort keys %some_ab_info ) {
    my $modi;
    my $id;
    my $count = 0;
    for my $mod_site1 ( sort numerically keys %{$some_ab_info{$gene}} ) {
      for my $aa ( sort keys %{$some_ab_info{$gene}{$mod_site1}} ) {
        if( $count == 0 ) {
          $modi = $aa_map{$aa} . $mod_site1;
        }
        else {
          $modi = $modi . "<br>" . $aa_map{$aa} . $mod_site1;
        }
        $count++;
      }
    }

    my @temp = split "\t", $gene;
    my $gene_info =
       "<a href=CGAP/Genes/GeneInfo?ORG=Hs&CID=$temp[1]>$temp[0]</a>";
    $antibody_line = $antibody_line .
       "<tr>" .
           "<td valign=bottom>$gene_info</td>" .
           "<td valign=bottom>$modi</td>" .
       "</tr>";
  }

  $antibody_line = $antibody_line . "</table>";

  my (@lines);

  push @lines, "<ul>";
  push @lines, "<li><b>Antibody Name:</b>";
  push @lines, "<blockquote>$name</blockquote>";
  push @lines, "<li><b>Antibody Targets:</b>";
  push @lines, "<blockquote>$antibody_line</blockquote>";
  push @lines, "<li><b>Antibody Description:</b>";
  push @lines, "<blockquote>$description</blockquote>";
  push @lines, "<li><b>Host:</b>";
  push @lines, "<blockquote>$host</blockquote>";
  push @lines, "<li><b>Catalog Name:</b>";
  push @lines, "<blockquote>$catalog</blockquote>";
  push @lines, "<li><b>Supplier Name:</b>";
  push @lines, "<blockquote>$sup_info</blockquote>";
  push @lines, "<li><b>Curator Name:</b>";
  push @lines, "<blockquote>$curator</blockquote>";
  push @lines, "</ul>";

  return join("\n", @lines);

}

######################################################################
sub getAntibodyInfo {
  my ($db, $all_ab_info) = @_;

  my @antibody_info;

  my ($ID, $GENE, $CLUSTER_NUMBER, $TARG_MOD_SITE1, $TARG_MOD_AA, 
      $AB_NAME, $HOST_NAME, $CATALOG, $SUPPLIER_ABBREV, $SUPPLIER_URL );

  my $sql_lines = "select unique a.ID, g.GENE, g.CLUSTER_NUMBER, " .
                  " b.TARG_MOD_SITE1, b.TARG_MOD_AA, " .
                  " a.AB_NAME, c.HOST_NAME, a.AB_CATALOG, " .
                  " d.SUPPLIER_ABBREV, d.SUPPLIER_URL " .
                  " from $CGAP_SCHEMA.AB_INFO a, " .
                  "      $CGAP_SCHEMA.AB_TARG_MOD b, " .
                  "      $CGAP_SCHEMA.AB_HOST c, " .
                  "      $CGAP_SCHEMA.AB_SUPPLIER d, " .
                  "      $CGAP_SCHEMA.AB_TARGET e, " .
                  "      $CGAP_SCHEMA.AB_INFO2TARGET f, " .
                  "      $CGAP_SCHEMA.HS_CLUSTER g " .
                  " where a.ID = f.INFO_ID and e.ID = f.TARGET_ID " .
                  " and e.TARG_LOCUSLINK = g.LOCUSLINK " .
                  " and d.ID = a.AB_SUPPLIER_ID " .
                  " and c.ID = a.AB_HOST_ID " .
                  " and b.TARG_ID = e.ID	" .
                  " and b.TARG_ID = f.TARGET_ID	" .
                  " order by g.GENE ";

  my $stm = $db->prepare($sql_lines);

  if (not $stm) {
    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    $db->disconnect();
    return "";
  }

  if(!$stm->execute()) {
 
    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    $db->disconnect(); 
    return "";
  }

  $stm->bind_columns( \$ID, \$GENE, \$CLUSTER_NUMBER, \$TARG_MOD_SITE1, 
                      \$TARG_MOD_AA, \$AB_NAME, \$HOST_NAME, \$CATALOG, 
                      \$SUPPLIER_ABBREV, \$SUPPLIER_URL );
 
 
  while($stm->fetch) {
    my $gene = $GENE . "\t" . $CLUSTER_NUMBER;
    my $suppl = $SUPPLIER_ABBREV . "\t" . $SUPPLIER_URL;
    $TARG_MOD_SITE1 =~ s/\s+//;
    $CATALOG =~ s/^\s+//;
    $CATALOG =~ s/\s+$//;
    $$all_ab_info{$gene}{$AB_NAME}{$HOST_NAME}{$CATALOG}{$suppl}{$TARG_MOD_SITE1}{$TARG_MOD_AA} = $ID; 
  }

  return @antibody_info;

}

######################################################################
sub getSomeAntibodyInfo {
  my ($db, $id, $supplier_abbrev, $some_ab_info) = @_;

  my @antibody_info;

  my ($AB_DESCRIPTION, $SUPPLIER_NAME, $SUPPLIER_URL, $AB_CURATOR);
  my ($GENE, $CLUSTER_NUMBER, $TARG_MOD_SITE1, $TARG_MOD_AA);

  my $sql_lines = 
        "select AB_DESCRIPTION from $CGAP_SCHEMA.AB_INFO " .
        " where ID = $id ";

  my $stm = $db->prepare($sql_lines);

  if (not $stm) {
    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    $db->disconnect();
    return "";
  }

  if(!$stm->execute()) {
 
    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    $db->disconnect(); 
    return "";
  }

  $stm->bind_columns( \$AB_DESCRIPTION ); 
 
  while($stm->fetch) {
    push @antibody_info, $AB_DESCRIPTION;
  }


  my $sql_lines = "select unique g.GENE, g.CLUSTER_NUMBER, " .
                  " b.TARG_MOD_SITE1, b.TARG_MOD_AA " .
                  " from $CGAP_SCHEMA.AB_INFO a, " .
                  "      $CGAP_SCHEMA.AB_TARG_MOD b, " .
                  "      $CGAP_SCHEMA.AB_TARGET e, " .
                  "      $CGAP_SCHEMA.AB_INFO2TARGET f, " .
                  "      $CGAP_SCHEMA.HS_CLUSTER g " .
                  " where a.ID = f.INFO_ID and e.ID = f.TARGET_ID " .
                  " and e.TARG_LOCUSLINK = g.LOCUSLINK " .
                  " and b.TARG_ID = e.ID        " .
                  " and b.TARG_ID = f.TARGET_ID " .
                  " and a.ID = $id " .
                  " order by g.GENE ";

  my $stm = $db->prepare($sql_lines);

  if (not $stm) {
    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    $db->disconnect();
    return "";
  }

  if(!$stm->execute()) {

    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    $db->disconnect();
    return "";
  }

  $stm->bind_columns( \$GENE, \$CLUSTER_NUMBER, \$TARG_MOD_SITE1,
                      \$TARG_MOD_AA );


  while($stm->fetch) {
    my $gene = $GENE . "\t" . $CLUSTER_NUMBER;
    $TARG_MOD_SITE1 =~ s/\s+//;
    $$some_ab_info{$gene}{$TARG_MOD_SITE1}{$TARG_MOD_AA} = 1;
  }

  my $sql_lines = 
        "select SUPPLIER_NAME, SUPPLIER_URL from $CGAP_SCHEMA.AB_SUPPLIER " .
        " where SUPPLIER_ABBREV = '$supplier_abbrev' ";

  my $stm = $db->prepare($sql_lines);

  if (not $stm) {
    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    $db->disconnect();
    return "";
  }

  if(!$stm->execute()) {

    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    $db->disconnect();
    return "";
  }

  $stm->bind_columns( \$SUPPLIER_NAME, \$SUPPLIER_URL );

  while($stm->fetch) {
    push @antibody_info, $SUPPLIER_NAME;
    push @antibody_info, $SUPPLIER_URL;
  }

  my $sql_lines =
        "select b.CURATOR_NAME from $CGAP_SCHEMA.AB_INFO a, " .
        " $CGAP_SCHEMA.AB_CURATOR b " .
        " where a.ID = $id and a.AB_CURATOR_ID = b.ID ";

  my $stm = $db->prepare($sql_lines);

  if (not $stm) {
    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    $db->disconnect();
    return "";
  }

  if(!$stm->execute()) {

    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    $db->disconnect();
    return "";
  }

  $stm->bind_columns( \$AB_CURATOR );

  while($stm->fetch) {
    push @antibody_info, $AB_CURATOR;
  }

  return @antibody_info;

}



######################################################################

sub convrt {
  my ($temp) = @_;

  $temp =~ s/ /+/g;
  $temp =~ s/-/%2D/g;
  $temp =~ s/'/%27/g;
  $temp =~ s/#/%23/g;

  return $temp
}
######################################################################
1;
