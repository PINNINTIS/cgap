#!/usr/local/bin/perl

use strict;
use FileHandle;
use CGAPConfig;
use Paging;
use DBI;
use Scan_Server;

######################################################################
# PathwayServer
#
######################################################################

my $BASE;

my %BUILDS;

######################################################################

## node_types 

#use constant REACTION  => 1;
#use constant ENZYME    => 2;
#use constant SUBSTRATE => 3;
#use constant REACTANT  => 3;
#use constant PRODUCT   => 4;
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

sub numerically   { $a <=> $b; }

#####################################################################
sub InitializeDatabase {
  Setup_Paths();
}

########################################################################
sub Setup_Paths {

  my ($arc_id, $arc_type, $arc_src, $arc_dest);
  my ($node_id, $node_type, $node_name, $node_name_lc);
  my ($path_id, $path_name, $locus_id, $c1, $c2, $c3, $c4);
  my ($ecno, $enzyme, $enzyme_lc, $cno, $compound);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "Cannot connect to Database\n";
    return "";
  }

  my $sql = "select * from $CGAP_SCHEMA.KeggArcs ";

  my $stm = $db->prepare($sql);

  if (!$stm->execute()) {
     ## print STDERR "$sql\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     return "";
  }

  $stm->bind_columns(\$arc_id, \$arc_type, \$arc_src, \$arc_dest);
  while ($stm->fetch) {
    $arc_type{$arc_id} = $arc_type;
    $arc_src{$arc_id}  = $arc_src;
    $arc_dest{$arc_id} = $arc_dest;
    push(@{$arc_id{$arc_src}}, $arc_id);
    push(@{$arc_id{$arc_dest}}, $arc_id);
  }


  my $sql = "select * from $CGAP_SCHEMA.KeggNodes ";

  my $stm = $db->prepare($sql);

  if (!$stm->execute()) {
     ## print STDERR "$sql\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     return "";
  }

  $stm->bind_columns(\$node_id, \$node_type, \$node_name);
  while ($stm->fetch) {
    $node_name_lc = lc $node_name;
    $node_type{$node_id} = $node_type;
    $node_name{$node_id} = $node_name_lc;
    $node_id{$node_name_lc} = $node_id;
  }


  my $sql = "select * from $CGAP_SCHEMA.KeggGeneProducts ";

  my $stm = $db->prepare($sql);

  if (!$stm->execute()) {
     ## print STDERR "$sql\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     return "";
  }

  $stm->bind_columns(\$node_id, \$locus_id);
  while ($stm->fetch) {
    $node_link{$node_id} = $locus_id;
  }


  my $sql = "select * from $CGAP_SCHEMA.KeggPaths ";

  my $stm = $db->prepare($sql);

  if (!$stm->execute()) {
     ## print STDERR "$sql\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     return "";
  }

  $stm->bind_columns(\$path_id, \$arc_id);
  while ($stm->fetch) {
    $arc_path{$arc_id} = $path_id;
  }


  my $sql = "select * from $CGAP_SCHEMA.KeggPathNames ";

  my $stm = $db->prepare($sql);

  if (!$stm->execute()) {
     ## print STDERR "$sql\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     return "";
  }

  $stm->bind_columns(\$path_id, \$path_name);
  while ($stm->fetch) {
    $path_name{$path_id} = $path_name;
  }


  my $sql = "select * from $CGAP_SCHEMA.KeggCoords ";

  my $stm = $db->prepare($sql);

  if (!$stm->execute()) {
     ## print STDERR "$sql\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
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


  my $sql = "select * from $CGAP_SCHEMA.KeggEnzymes ";

  my $stm = $db->prepare($sql);

  if (!$stm->execute()) {
     ## print STDERR "$sql\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     return "";
  }

  $stm->bind_columns(\$ecno, \$enzyme);
  while ($stm->fetch) {
    $enzyme_lc = lc $enzyme;
    $enzymes{$enzyme_lc} = $ecno;
    $enzymes{$ecno} = $enzyme if (not defined $enzymes{$ecno});
  }


  my $sql = "select * from $CGAP_SCHEMA.KeggEntries ";

  my $stm = $db->prepare($sql);

  if (!$stm->execute()) {
     ## print STDERR "$sql\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     return "";
  }

  $stm->bind_columns(\$cno, \$compound);
  while ($stm->fetch) {
    $compounds{$compound} = $cno;
    $compounds{$cno} = $compound if (not defined $compounds{$cno});
  }


  $db->disconnect();
}


########################################################################
sub Query_Paths {

  my ($from_node, $to_node, $Avoid) = @_;

  my $test = Scan ($from_node, $to_node, $Avoid);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  my ($dest_node, $dest_arc, $from_arc, $arc);
  my ($found, $found_path, $node);
  my @avoid_nodes = @$Avoid;

  if (defined $arc_id{$from_node}) {
QUARC: foreach $from_arc (@{$arc_id{$from_node}}) {
      foreach $arc (@Queried) {
        next QUARC if ($arc == $from_arc);
      }
      foreach $node (@avoid_nodes) {
        next QUARC if abs $arc_src{$from_arc} == abs $node;
      }
      foreach $node (@possible_path) {
        next QUARC if abs $arc_dest{$from_arc} == abs $node;
      }
      push @Queried, $from_arc;

      if ($arc_src{$from_arc} == $from_node
      &&  (defined $from_type{$arc_type{$from_arc}})
      &&  $arc_path{$from_arc} eq $dest_path
      &&  $node_type{$arc_dest{$from_arc}} != COENZYME) {
        $dest_node = $arc_dest{$from_arc};
      } else {
        next;
      }

      foreach $dest_arc (@{$arc_id{$dest_node}}) {  
        if ($from_arc != $dest_arc) {
          if ((defined $to_type{$arc_type{$dest_arc}})
          &&  $arc_dest{$dest_arc} == $dest_node
          &&  $arc_path{$dest_arc} eq $dest_path
          &&  $node_type{$arc_src{$dest_arc}} != COENZYME) {
            if ($arc_src{$dest_arc} == $to_node) {
              push @possible_path, $dest_node;
              $found = 0;
              foreach $found_path (@possible_paths) {
                if (join(", ", @{$found_path})
                eq  join(", ", @possible_path)) {
                  $found = 1;
                  last;
                }
              }
              if ($found == 0) {
                push @possible_paths, [ @possible_path ];
              }
              pop @possible_path;
              push @Queried, $dest_arc;
              next;
            } else {
              push @possible_path, $dest_node;
              Query_Paths($arc_src{$dest_arc},$to_node,\@avoid_nodes);
              last if (@possible_path < 2);
              push @Queried, $dest_arc;
              next;
            }
          }
        }
      }
    }
  }
  if (@possible_path > 2) {
    pop @possible_path;
  } else {
    undef @possible_path;
  }
}

########################################################################
sub Find_Paths {
  my ($from_node, $to_node, $enzyme) = @_;
  my $test = Scan ($from_node, $to_node, $enzyme);
  if( $test =~ /Error in input/ ) {
    return $test;
  }
  my ($dest_node, $node);
  my ($from_arc, $dest_arc, $arc);
  my ($found, $found_path, @Avoid);

  if (defined $arc_id{$from_node}) {
ARC: foreach $from_arc (@{$arc_id{$from_node}}) {
      if ($arc_src{$from_arc} == $from_node
      && (defined $from_type{$arc_type{$from_arc}})
      &&  $node_type{$arc_dest{$from_arc}} != COENZYME) {
        $dest_node = $arc_dest{$from_arc};
        $dest_path = $arc_path{$from_arc};
      } else {
        next;
      }

      undef @Queried;
      undef @Avoid;
      foreach $dest_arc (@{$arc_id{$dest_node}}) {  
        if ($from_arc != $dest_arc) {
          if ((defined $to_type{$arc_type{$dest_arc}})
          &&  $arc_dest{$dest_arc} == $dest_node
          &&  $arc_path{$dest_arc} eq $dest_path
          &&  $node_type{$arc_src{$dest_arc}} != COENZYME) {
            if ($arc_src{$dest_arc} == $to_node) {
              push @possible_path, $dest_path
                 if (not defined @possible_path);
              push @possible_path, $dest_node;
              if (defined @possible_path) {
                $found = 0;
                foreach $found_path (@possible_paths) {
                  if (join(", ", @{$found_path})
                  eq  join(", ", @possible_path)) {
                    $found = 1;
                    last;
                  }
                }
                if ($found == 0) {
                  push @possible_paths, [ @possible_path ];
                  undef @possible_path;
                }
              }
            } else {
              $depth = 0;
              push @Queried, $from_arc;
              push @Queried, $dest_arc;
              push @Avoid, $from_node;
              push @possible_path, $dest_path
                 if (not defined @possible_path);
              push @possible_path, $dest_node;
              Query_Paths($arc_src{$dest_arc},$to_node,\@Avoid);
            }
          }
        }
      }
    }
  }
}

########################################################################
sub Paths {
  my ($from, $to) = @_;
  my $test = Scan ($from, $to);
  if( $test =~ /Error in input/ ) {
    return $test;
  }
  my $from_lc = lc $from;
  my $to_lc = lc $to;
  my ($from_node, $to_node, $found);
  my ($from_cno, $to_cno);
  my $enzyme = 0;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);

  if(not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  if ($from =~ /^[1-6]\.[0-9-]+\.[0-9-]+\.[0-9-]+$/) {    ## ecno
    $enzyme = 1;
    $from_cno = $from;
  }
  elsif ($from_lc =~ /^c[0-9]+$/) {   ## cno
    $from_cno = $from;
  }
  elsif ($compounds{$from_lc}) {
    $from_cno = $compounds{$from_lc};
  }
  elsif ($enzymes{$from_lc}) {
    $from_cno = $enzymes{$from_lc};
    $enzyme = 1;
  }
  elsif ($from =~ /^[0-9]+$/) {   ## locus-id
    my $sql = "select distinct ecno " .
              "from $CGAP_SCHEMA.KeggGenes " .
              "where organism = 'Hs' " .
              "and locus_id = $from";
    my $stm = $db->prepare($sql);

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$found);
    $stm->fetch;
    $stm->finish;
    if ($found ne '') {
      $from_cno = $found;
      $enzyme = 1;
    }
  }
  elsif ($from_lc =~ /^[\w\s-]+$/) {   ## symbol or word
    my $dqfrom_lc = $from_lc;
    $dqfrom_lc =~ s/'/''/g;
    my $sql = "select distinct ecno " .
              "from $CGAP_SCHEMA.KeggGenes " .
              "where organism = 'Hs' " .
              "and (lower(symbol) = '$dqfrom_lc' " .
              "or lower(name) = '$dqfrom_lc') ";

    my $stm = $db->prepare($sql);

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$found);
    $stm->fetch;
    $stm->finish;
    if ($found ne '') {
      $from_cno = $found;
      $enzyme = 1;
    }
  }

  if ($to =~ /^[1-6]\.[0-9-]+\.[0-9-]+\.[0-9-]+$/) {    ## ecno
    $enzyme = 1;
    $to_cno = $to;
  }
  elsif ($to_lc =~ /^c[0-9]+$/) {   ## cno
    $to_cno = $to;
  }
  elsif ($compounds{$to_lc}) {
    $to_cno = $compounds{$to_lc};
  }
  elsif ($enzymes{$to_lc}) {
    $to_cno = $enzymes{$to_lc};
    $enzyme = 1;
  }
  elsif ($to =~ /^[0-9]+$/) {   ## locus-id
    my $sql = "select distinct ecno " .
              "from $CGAP_SCHEMA.KeggGenes " .
              "where organism = 'Hs' " .
              "and locus_id = $to";
    my $stm = $db->prepare($sql);

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$found);
    $stm->fetch;
    $stm->finish;
    if ($found ne '') {
      $to_cno = $found;
      $enzyme = 1;
    }
  }
  elsif ($to_lc =~ /^[\w\s-]+$/) {   ## symbol or word
    my $dqto_lc = $to_lc;
    $dqto_lc =~ s/'/''/g;
    my $sql = "select distinct ecno " .
              "from $CGAP_SCHEMA.KeggGenes " .
              "where organism = 'Hs' " .
              "and (lower(symbol) = '$dqto_lc' " .
              "or lower(name) = '$dqto_lc') ";

    my $stm = $db->prepare($sql);

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$found);
    $stm->fetch;
    $stm->finish;
    if ($found ne '') {
      $to_cno = $found;
      $enzyme = 1;
    }
  }

  $db->disconnect();

# return INVALID if ($enzyme || $from_cno eq '');
# return INVALID if ($enzyme || $to_cno eq '');
  return INVALID if (($from_cno eq '') || ($to_cno eq ''));

  $from_cno = lc $from_cno;
  $to_cno = lc $to_cno;

  if (defined $node_id{$from_cno}) {
    $from_node = $node_id{$from_cno};
  }
  return ERROR if ($node_type{$from_node} == COENZYME);

  if (defined $node_id{$to_cno}) {
    $to_node = $node_id{$to_cno};
  }
  return ERROR if ($node_type{$to_node} == COENZYME);

  undef %from_type;
  undef %to_type;

  $from_type{2} = 1;    ## SUBSTRATE_FOR
  $to_type{3} = 1;      ## PRODUCT_OF
  if ($enzyme) {
    $from_type{1} = 1;  ## CATALYST
    $to_type{1} = 1; 
  }
  Find_Paths($from_node,$to_node,$enzyme);
  return OK;

}

########################################################################
sub Show_Paths {
    my ($from, $to) = @_;
    my $test = Scan ($from, $to);
    if( $test =~ /Error in input/ ) {
      return $test;
    }
    my ($cno_from, $cno_to);
    my ($pathname, $pathfile, $path, $path_id, $pathlen);
    my ($reactant, $product, $locus_id);
    my ($compound, $this_enzyme);
    my ($just_shown, $just_in, $have_it, $pkey);
    my (%reaction_enzyme, %possible_paths, @sorted_paths);
    my ($possible_path, $node, $arc);
    my (@rows, $row, $hold_row, $graphic);

    if (@possible_paths) {
      my $from = lc $from;
      my $to = lc $to;
      if ($from =~ /^c[0-9]+$/) {   ## cno
        $cno_from = uc $from;
      } else {
        $cno_from = $compounds{$from};
      }
      if ($to =~ /^c[0-9]+$/) {   ## cno
        $cno_to = uc $to;
      } else {
        $cno_to = $compounds{$to};
      }
      push @rows, "<table border=1 cellspacing=1 cellpadding=4>" .
         "<tr bgcolor=\"#38639d\">" .
         "<td align=center><font color=\"white\"><b>Pathway</b></font></td>" .
         "<td align=center><font color=\"white\"><b>Graphic</b></font></td></tr>" ;

      my $x = 0;
      foreach $possible_path (@possible_paths) {
        $path_id =  @{$possible_path}[0];
        $pathname = $path_name{$path_id};
        $pathlen = sprintf "%0.3d",scalar @{$possible_path};
        $possible_paths{$pathname.';'.$pathlen.';'.$x++} = $possible_path;
      }
      foreach $pkey (sort keys %possible_paths) {
        push @sorted_paths, $possible_paths{$pkey};
      }
      foreach $possible_path (@sorted_paths) {
        my (%reactants, %products, @reactants, @products, $actor);
        my ($coenzyme, $coenzymes, %coenzymes_in, %coenzymes_out);
        my (@coords, $coords, $x1, $y1, $x2, $y2);
        my (@coordinates, $coords_row, $more_coords);
        my ($left, $bottom, $right, $top);

        $path_id = shift @{$possible_path};
        $pathname = '';
        $row = '<tr><td><font size=-1 face=Garamond>';
        foreach $node (@{$possible_path}) {
          foreach $arc (@{$arc_id{$node}}) {
            if ($pathname eq '') {
              $pathname = $path_name{$path_id};
              if (defined $coords{$path_id}{$cno_from}) {
                push @coords, $coords{$path_id}{$cno_from};
                $more_coords = 1 if ($coords{$path_id}{$cno_from} =~ m/;/);
              }
              if (defined $coords{$path_id}{$cno_to}) {
                push @coords, $coords{$path_id}{$cno_to};
                $more_coords = 1 if ($coords{$path_id}{$cno_to} =~ m/;/);
              }
            }
            if ($arc_type{$arc} == SUBSTRATE_FOR
            &&  $arc_path{$arc} eq $path_id) {
              $reactant = $arc_src{$arc};
              if ($node_type{$reactant} != COENZYME) {
                $have_it = 0;
                foreach $actor (@{$reactants{$node}}) {
                  if ($actor eq $node_name{$reactant}) {
                    $have_it = 1;
                    last;
                  }
                }
                if (not $have_it) {
                  push @{$reactants{$node}}, $node_name{$reactant};
                }
              }
              else {
                $have_it = 0;
                foreach $coenzyme (@{$coenzymes_in{$node}}) {
                  if ($coenzyme eq $node_name{$reactant}) {
                    $have_it = 1;
                    last;
                  }
                }
                if (not $have_it) {
                  push @{$coenzymes_in{$node}}, $node_name{$reactant};
                } 
              } 
            }
            elsif ($arc_type{$arc} == PRODUCT_OF
               &&  $arc_path{$arc} eq $path_id) {
              $product = $arc_src{$arc};
              if ($node_type{$product} != COENZYME) {
                $have_it = 0;
                foreach $actor (@{$products{$node}}) {
                  if ($actor eq $node_name{$product}) {
                    $have_it = 1;
                    last;
                  }
                }
                if (not $have_it) {
                  push @{$products{$node}}, $node_name{$product};
                }
              } else {
                $have_it = 0;
                foreach $coenzyme (@{$coenzymes_out{$node}}) {
                  if ($coenzyme eq $node_name{$product}) {
                    $have_it = 1;
                    last;
                  }
                }
                if (not $have_it) {
                  push @{$coenzymes_out{$node}}, $node_name{$product};
                } 
              } 
            } 
            elsif ($arc_type{$arc} == CATALYST
               &&  $arc_path{$arc} eq $path_id) {
              if (not defined $reaction_enzyme{$node}) {
                $reaction_enzyme{$node} = $node_name{$arc_src{$arc}};
              } 
              $locus_id = $node_link{$arc_src{$arc}};
##            if (defined $from_type{1}) {  ## CATALYST
                if (defined $coords{$path_id}{$locus_id}) {
                  push @coords, $coords{$path_id}{$locus_id};
                }
                elsif (defined $coords{$path_id}{$reaction_enzyme{$node}}) {
                  push @coords, $coords{$path_id}{$reaction_enzyme{$node}};
                }
##            }
            } 
          }
        }

        my $coordlen = scalar @coords - 2;
        my $pathlen  = scalar @{$possible_path};
        $more_coords = 1 if ($coordlen < $pathlen);
        $just_shown = '';
        foreach $node (@{$possible_path}) {
          $just_in = 1;
          foreach $compound (@{$reactants{$node}}) {
             if ($just_in == 0) {
                if ($compound eq $just_shown) {
                  $just_shown = '';
                } else {
                  $row .= " + ";
                  $row .= $compounds{uc $compound};
                }
             } else {
                $just_in = 0;
                if ($compound eq $just_shown) {
                  $just_shown = '';
                } else {
                  $row .= "<br>" if (length $row > 36);  ## <tr><td ...>
                  $row .= $compounds{uc $compound};
                }
             }
             if ($more_coords) {
                if (defined $coords{$path_id}{uc $compound}) {
                   push @coords, $coords{$path_id}{uc $compound};
                }
             }
          }

          $this_enzyme = $reaction_enzyme{$node};
          $coenzymes = '';
          if ((defined $coenzymes_in{$node}) || (defined $coenzymes_out{$node}))
          {
            if (defined $coenzymes_in{$node}) {
              foreach $coenzyme (@{$coenzymes_in{$node}}) {
                $coenzymes .= ' + ' if ($coenzymes ne '');
                $coenzymes .= $compounds{uc $coenzyme};
              }
              $row .= " + $coenzymes";
            }
            $coenzymes = '';
            if (defined $coenzymes_out{$node}) {
              foreach $coenzyme (@{$coenzymes_out{$node}}) {
                $coenzymes .= ' + ' if ($coenzymes ne '');
                $coenzymes .= $compounds{uc $coenzyme};
              }
            }
            $row .= "<font color=#339999>" . " <=" . $this_enzyme . "=> " . "</font>";
          } else {
            $row .= "<font color=#339999>" . " <=" . $this_enzyme . "=> " . "</font>";
          }

          $just_in = 1;
 
          foreach $compound (@{$products{$node}}) {
             if (not $just_in) {
                $row .= " + ";
             } else {
                $just_in = 0;
             }
             $row .= $compounds{uc $compound};
             if ($coenzymes ne '') {
               $row .= " + $coenzymes";
               undef $coenzymes;
             }
             if ($more_coords) {
                if (defined $coords{$path_id}{uc $compound}) {
                   push @coords, $coords{$path_id}{uc $compound};
                }
             }
          }
          if ($coenzymes ne '') {  ## when the products are all coenzymes
            $row .= $coenzymes;
            undef $coenzymes;
          }
        }

        $left = 9999; $bottom = 0;
        $top = 9999;  $right = 0;
        foreach $coords_row (@coords) {
          @coordinates = split ";", $coords_row;
          next if ($#coordinates > 0);
          foreach $coords (@coordinates) {
            ($x1, $y1, $x2, $y2) = split ",", $coords;
            if ($x1 < $left) {
              $left = $x1;
            }
            if ($y1 < $top) {
              $top = $y1;
            }
            if ($x2 > $right) {
              $right = $x2;
            }
            if ($y2 > $bottom) {
              $bottom = $y2;
            }
          }
        }
        if ($more_coords) {
        my $rl = $right - (($right - $left) / 2);
        my $bt = $bottom - (($bottom - $top) / 2);
        foreach $coords_row (@coords) {
          my $closest_coords = '';
          my $closest_x = 9999;
          my $closest_y = 9999;
          @coordinates = split ";", $coords_row;
          next if ($#coordinates == 0);
          foreach $coords (@coordinates) {
            ($x1, $y1, $x2, $y2) = split ",", $coords;
            if ((($y1 > $top) && ($y2 < $bottom))
            &&  (($x1 > $left) && ($x2 < $right))) {
              $closest_coords = '';
              last;
            }
            if (abs($x1 - $rl) + abs($y1 - $bt) < $closest_x + $closest_y) {
              $closest_x = abs($x1 - $rl) if (abs($x1 - $rl) < $closest_x);
              $closest_y = abs($y1 - $bt) if (abs($y1 - $bt) < $closest_y);
              $closest_coords = $coords;
            }
          }
          next if ($closest_coords eq '');
          ($x1, $y1, $x2, $y2) = split ",", $closest_coords;
          if ($x1 < $left) {
            $left = $x1;
          }
          if ($y1 < $top) {
            $top = $y1;
          }
          if ($x2 > $right) {
            $right = $x2;
          }
          if ($y2 > $bottom) {
            $bottom = $y2;
          }
        }
        }
        $coords = "$left,$top,$right,$bottom";
        $row .= "</font></td>";
        $row .= "<td><a class=\"keggpath\" href=javascript:FramedPath(\"$BASE/Pathways/Kegg/$path_id\",\"$coords\")>$pathname</a></td></tr>";
        push @rows, $row;
      }
      push @rows, "</table>";
      return join "\n", @rows;
    } else {
      return 'No Pathways Found';
    }
}

########################################################################
sub List_Paths {
  my ($with) = @_;
  my $test = Scan ($with);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  my $with_lc = lc $with;
  my (@rows, $row, @cnos, $cno, $llno);
  my ($path_id, $pathway_name);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);

  if(not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  if ($with =~ /^[1-6]\.[0-9-]+\.[0-9-]+\.[0-9-]+$/) {    ## ecno
    $cno = $with;
    my $sql = "select distinct locus_id " .
              "from $CGAP_SCHEMA.KeggGenes " .
              "where organism = 'Hs' " .
              "and ecno = '$with'";
    my $stm = $db->prepare($sql);

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$llno);
    while ($stm->fetch) {
      push @cnos, $llno;
    }
    $stm->finish;
  }
  elsif ($with_lc =~ /^c[0-9]+$/) {   ## cno
    $cno = uc($with);
  }
  elsif ($compounds{$with_lc}) {
    $cno = $compounds{$with_lc};
  }
  elsif ($enzymes{$with_lc}) {   ## enzyme name
    $cno = $enzymes{$with_lc};
    my $dqwith_lc = $with_lc;
    $dqwith_lc =~ s/'/''/g;
    my $sql = "select distinct locus_id " .
              "from $CGAP_SCHEMA.KeggGenes " .
              "where organism = 'Hs' " .
              "and lower(name) = '$dqwith_lc'";

    my $stm = $db->prepare($sql);

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$llno);
    while ($stm->fetch) {
      push @cnos, $llno;
    }
    $stm->finish;
  }
  elsif ($with =~ /^[0-9]+$/) {   ## locus-id
    $llno = $with;
    my $sql = "select distinct ecno " .
              "from $CGAP_SCHEMA.KeggGenes " .
              "where organism = 'Hs' " .
              "and locus_id = $with";
    my $stm = $db->prepare($sql);

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$cno);
    $stm->fetch;
    $stm->finish;
  }
  elsif ($with_lc =~ /^[\w\s-]+$/) {   ## symbol or word
    my $dqwith_lc = $with_lc;
    $dqwith_lc =~ s/'/''/g;
    my $sql = "select distinct ecno, locus_id " .
              "from $CGAP_SCHEMA.KeggGenes " .
              "where organism = 'Hs' " .
              "and (lower(symbol) = '$dqwith_lc' " .
              "or lower(name) = '$dqwith_lc')";

    my $stm = $db->prepare($sql);

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$cno, \$llno);
    $stm->fetch;
    $stm->finish;
    if ($cno eq '') {
      $sql = "select c.locuslink " .
             "from $CGAP_SCHEMA.hs_cluster c, " .
                  "$CGAP_SCHEMA.hs_gene_alias g " .
             "where g.gene_uc like upper('$with') " .
             "and g.cluster_number = c.cluster_number " ;

      $stm = $db->prepare($sql);

      if (!$stm->execute()) {
         ## print STDERR "$sql\n";
         ## print STDERR "$DBI::errstr\n";
         print "execute call failed\n";
         return "";
      }

      $stm->bind_columns(\$cno);
      $stm->fetch;
      $stm->finish;
    }
  }

  push @rows, "<TR><TD valign=top align=left><UL>";
  if ($cno ne '') {
    my $dqwith = $with;
    $dqwith =~ s/'/''/g;
    my $sql_pathway = "select distinct p.path_id, p.pathway_name " .
                      "from $CGAP_SCHEMA.KeggComponents k, " .
                      "$CGAP_SCHEMA.KeggPathNames p " .
                      "where k.path_id = p.path_id " .
                      "and (k.ecno = upper('$cno') " .
                      "or   k.ecno = upper('$dqwith')) " ;

    my $stm = $db->prepare($sql_pathway);

    if (!$stm->execute()) {
       ## print STDERR "$sql_pathway\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$path_id, \$pathway_name);

    my $pcnt = 0;
    while ($stm->fetch) {
      my ($coords);
      if (defined $coords{$path_id}{$cno}) {
        $coords = join(",", split("\t",$coords{$path_id}{$cno}));
      } elsif (defined $coords{$path_id}{$with}) {
        $coords = join(",", split("\t",$coords{$path_id}{$with}));
      } elsif (defined $coords{$path_id}{$llno}) {
        $coords = join(",", split("\t",$coords{$path_id}{$llno}));
      } else {
        for my $entry (@cnos) {
          if (defined $coords{$path_id}{$entry}) {
            $coords = join(",", split("\t",$coords{$path_id}{$entry}));
          }
        }
      }
      if ($pathway_name) {
        $row = "<LI><a class=\"genesrch\" href=javascript:ColoredPath(\"$BASE/Pathways/Kegg/$path_id\",\"$coords\",\"$cno\")>$pathway_name</a>";
        push @rows, $row;
        $pcnt++;
      }
    }
    if ($pcnt == 0) {
      push @rows, "<LI><B>No Pathways Found</B>";
    }
  }
  else {
    push @rows, "<LI><b>No Pathways Found</b>";
  }
  push @rows, "</UL></TD></TR>";

  $db->disconnect();

  return join "\n", @rows;
}

########################################################################
sub ComputePathway_1 {

  my ($base, $from, $to, $with) = @_;

  my $test = Scan ($base, $from, $to, $with);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  InitializeDatabase();
  $BASE = $base;

  if ($with ne '') {
    return "<table border=0 width=100%>" . List_Paths($with) . "</table>";
  } else {
    my $returned = Paths($from, $to);
    if ($returned == OK) {
      return Show_Paths($from, $to);
    } elsif ($returned == INVALID) {
      return "<table><tr><td colspan=4>Recognizable Compound names or numbers (C00074) and Enzyme names or numbers (4.2.1.26) are the only valid possibilities for starting and ending pathways.  Please reconsider your request or visit <a href=\"PathFinderHowTo\">All About the Pathway Searcher Tool.</A></td></tr></table><P><CENTER>Return to the <a href=Pathway_Searcher>Pathway Searcher</A></CENTER>";
    } else {
      return "<table class=\"keggpath\"><tr><td colspan=4>In the interest of efficiency, compounds we have considered to be 'coenzymes' or 'cofactors' have been eliminated as possibilities for starting or ending pathways.  Please reconsider your request.</td></tr></table>" .
"<p><center><table cellspacing=2 cellpadding=2 bordercolor=#38639d border=5 frame=border rules=cols>" .
"<tr bgcolor=\"#38639d\">" .
"<td align=center colspan=4><font color=\"white\"><b>Our Coenzymes and Cofactors</b></font></td>" .
"<tr><td>Acceptor</td> <td>Donor</td> <td>IDP</td> <td>O2-</td></tr>" .
"<tr><td>Acetyl-CoA</td> <td>&nbsp;</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>ADP</td> <td>dADP</td> <td>IMP</td> <td>OH-</td></tr>" .
"<tr><td>Aluminum</td> <td>dAMP</td> <td>ITP</td> <td>Orthophosphate</td></tr>" .
"<tr><td>AMP</td> <td>dATP</td> <td>Iodine</td> <td>Oxidized donor</td></tr>" .
"<tr><td>Arsenic</td> <td>dCDP</td> <td>Iron</td> <td>Oxygen</td></tr>" .
"<tr><td>ATP</td> <td>dCMP</td> <td>Lead</td> <td>Phosphorus</td></tr>" .
"<tr><td>Boron</td> <td>dCTP</td> <td>Magnesium</td> <td>Potassium</td></tr>" .
"<tr><td>Calcium</td> <td>dGDP</td> <td>Manganese</td> <td>PQQ</td></tr>" .
"<tr><td>cAMP</td> <td>dGMP</td> <td>Mercury</td> <td>PQQH2</td></tr>" .
"<tr><td>Carbon</td> <td>dGTP</td> <td>NAD+</td> <td>Pyrophosphate</td></tr>" .
"<tr><td>CDP</td> <td>dIDP</td> <td>NADH</td> <td>Reduced acceptor</td></tr>" .
"<tr><td>Chromium</td> <td>dITP</td> <td>NADP+</td> <td>Silicon</td></tr>" .
"<tr><td>CMP</td> <td>dTDP</td> <td>NADPH</td> <td>Silver</td></tr>" .
"<tr><td>CO2</td> <td>dTMP</td> <td>NDP</td> <td>Sodium</td></tr>" .
"<tr><td>CoA</td> <td>dTTP</td> <td>NH3</td> <td>Sulfur</td></tr>" .
"<tr><td>Cobalt</td> <td>dUDP</td> <td>NH4+</td> <td>ThPP</td></tr>" .
"<tr><td>Copper</td> <td>dUMP</td> <td>Nickel</td> <td>UDP</td></tr>" .
"<tr><td>CTP</td> <td>dUTP</td> <td>Nitrogen</td> <td>UMP</td></tr>" .
"<tr><td>&nbsp;</td> <td>dXDP</td> <td>NMN</td> <td>UTP</td></tr>" .
"<tr><td>&nbsp;</td> <td>dXTP</td> <td>NMP</td> <td>Vanadium</td></tr>" .
"<tr><td>&nbsp;</td> <td>FAD</td> <td>&nbsp;</td> <td>XMP</td></tr>" .
"<tr><td>&nbsp;</td> <td>FADH2</td> <td>&nbsp;</td> <td>Zinc</td></tr>" .
"<tr><td>&nbsp;</td> <td>Fluoride</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>GDP</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>GMP</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>GTP</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>H+</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>H2CO3</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>H2O</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>H2O2</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>HCO3-</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>HCl</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>Hydrogen</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"<tr><td>&nbsp;</td> <td>Hydrogen Cyanide</td> <td>&nbsp;</td> <td>&nbsp;</td></tr>" .
"</table><P><a href=Kegg_Pathways>Return to Kegg Pathways</a></center>";
    }
  }
}

######################################################################
sub GetKeggCompound_1 {

  my ($base, $cno) = @_;

  my $test = Scan ($base, $cno);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  $BASE = $base;

  my (@rows, $row, $graphic);
  my ($path_id, $pathway_name);
  my ($name, $coords);

  if ($cno ne '') {
    my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);

    if (not $db or $db->err()) {
      ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print "Cannot connect to database\n";
      return "";
    }

    my $dqcno = $cno;
    $dqcno =~ s/ /','/g;
    my $sql = "select distinct name " .
              "from $CGAP_SCHEMA.KeggCompounds " .
              "where cno in ('$dqcno') ";

    my $stm = $db->prepare($sql);

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    push @rows, "<table border=0 width=100%>" .
      "<tr bgcolor=\"#38639d\">" .
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
 
    my $pcnt = 0;
    my $sql_pathway = "select distinct p.path_id, p.pathway_name " .
                      "from $CGAP_SCHEMA.KeggComponents k, " .
                      "$CGAP_SCHEMA.KeggPathNames p " .
                      "where k.path_id = p.path_id " .
                      ## "and k.ecno in upper('$dqcno') " .
                      "and k.ecno in ('$dqcno') " .
                      "order by p.pathway_name";

    my $stm = $db->prepare($sql_pathway);

    if (!$stm->execute()) {
       ## print STDERR "$sql_pathway\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$path_id, \$pathway_name);

    push @rows,
      "<table border=0 width=100%>" .
      "<tr bgcolor=\"#38639d\">" .
      "<td align=center colspan=4><font color=\"white\"><b>Pathways involving Compound $cno</b></font></td></tr>" .
      "<tr><td>&nbsp;</td></tr>" ;
    while ($stm->fetch) {
      if ($coords{$path_id}{$cno}) {
        $coords = join(",", split("\t",$coords{$path_id}{$cno}));
      }
      if ($pathway_name) {
        $row = "<tr><td width=8%><img src=\"" . IMG_DIR . "/Kegg/bullet.gif\" alt=\"bullet\" height=10 width=10 align=right border=0></td><td><a class=\"genesrch\" href=javascript:ColoredPath(\"$BASE/Pathways/Kegg/$path_id\",\"$coords\",\"$cno\")>$pathway_name</a></td></tr>";
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
      "<tr bgcolor=\"#38639d\">" .
      "<td align=center><font color=\"white\"><b>Compound Structure</b></font></td></tr>" .
      "<tr><td>&nbsp;</td></tr>" ;
    if( $cno =~ /\s+/ ) {
      my @tmp_cno = split " ", $cno;
      for( my $i=0; $i<@tmp_cno; $i++ ) {
        push @rows, "<tr><td align=center><img src=\"" . KEGG_DIR . "/Compounds/$tmp_cno[$i]\.gif\" alt=\"$tmp_cno[$i]\" align=center border=0></td></tr>";
      }
      push @rows, "</table>";
    }
    else {
      push @rows, "<tr><td align=center><img src=\"" . KEGG_DIR . "/Compounds/$cno\.gif\" alt=\"Compounds_$cno\" align=center border=0></td></tr></table>";
    }
  }
  else {
    push @rows, "<table><tr><td class=\"keggpath\">No Compound Found</td></tr></table>";
  }

  return join "\n", @rows;
}

######################################################################
sub GetBioCartaPathways {
  my ($base, $gene) = @_;

  my $test = Scan ($base, $gene);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  $BASE = $base;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  my ($pathway_page);
  my ($pathway_name, $pathway_display);
  my ($sql_pathway, $first, $no_h, $no_m, $pnum, $pair);
  my (%paths, %m_paths);

  if ($gene =~ /^[0-9]+$/) {   ## locus-id
    $sql_pathway = "select distinct p.pathway_name, p.pathway_display " .
                   "from $CGAP_SCHEMA.BioPaths p " .
                   "where bc_id in ( " .
                   "  select bc_id " .
                   "  from $CGAP_SCHEMA.BioGenes g, " .
                   "       $CGAP_SCHEMA.hs_cluster c " .
                   "  where g.locus_id = c.locuslink " .
                   "  and g.locus_id = $gene " .
                   ") " .
                   "order by upper(p.pathway_display)";
  } elsif ($gene =~ /^[\w\s-]+$/) {   ## symbol or word
    $sql_pathway = "select distinct p.pathway_name, p.pathway_display " .
                   "from $CGAP_SCHEMA.BioPaths p " .
                   "where bc_id in ( " .
                   "  select bc_id " .
                   "  from $CGAP_SCHEMA.BioGenes g, " .
                   "       $CGAP_SCHEMA.hs_cluster c, " .
                   "       $CGAP_SCHEMA.hs_gene_alias a " .
                   "  where g.locus_id = c.locuslink " .
                   "  and c.cluster_number = a.cluster_number " .
                   "  and a.gene_uc = upper('$gene') " .
                   ") " .
                   "order by upper(p.pathway_display)";
  }

  $pathway_page = "<TR><TD valign=top align=left><UL>";
  if ($sql_pathway) {
    my $stm = $db->prepare($sql_pathway);

    if (!$stm->execute()) {
       ## print STDERR "$sql_pathway\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }

    $stm->bind_columns(\$pathway_name, \$pathway_display);

    $first = 0; $pnum = 0;
    while ($stm->fetch) {
      if ($pathway_display) {
        if ($pathway_name =~ /^h_/) {
          $no_h = substr($pathway_name,2);
          $paths{$pnum++} = $no_h . ',' . $pathway_display;
        } elsif ($pathway_name =~ /^m_/) {
          $no_m = substr($pathway_name,2);
          $m_paths{$no_m} = 1;
        }
      }
    }
    foreach $pnum (sort numerically keys %paths) {
      ($pathway_name,$pathway_display) = split ',', $paths{$pnum};
      $first = 1;
      $pathway_page .= 
      "<LI><A class=genesrch href=\"" . $BASE .
      "/Pathways/BioCarta/h_$pathway_name\">" . $pathway_display . "</A> " .
      "<A href=\"" . $BASE . "/Pathways/BioCarta/h_$pathway_name\"> " .
      "<IMG SRC=\"" . IMG_DIR . "/BioCarta/buttonH.gif\" alt=\"buttonH\" border=0 title=\"Human Pathway\"></A> " ;
      if ($m_paths{$pathway_name}) {
        $pathway_page .= 
        "<A class=genesrch href=\"" . $BASE .
        "/Pathways/BioCarta/m_$pathway_name\">" .
        "<IMG SRC=\"" . IMG_DIR . "/BioCarta/buttonM.gif\" alt=\"buttonM\" border=0 title=\"Mouse Pathway\"></A>";
      }
    }
    $stm->finish;
 
    if (not $first) {
      $pathway_page .= "<LI><B>No Pathways Found</B>";
    }
  } else {
    $pathway_page .= "<LI><B>No Pathways Found</B>";
  }
  $pathway_page .=  "</UL></TD></TR>\n";

  $db->disconnect();

  return $pathway_page;
}

######################################################################
sub GetPathwayGenes_1 {
  my ($base, $gene) = @_;

  my $test = Scan ($base, $gene);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  $BASE = $base;

  my ($pathway_page);

  $pathway_page  = "<TR><TH align=left>BioCarta Pathways</TH></TR>";
  $pathway_page .= GetBioCartaPathways($base, $gene);
  ## $pathway_page .= "<TR><TH align=left>KEGG Pathways</TH></TR>";
  ## $pathway_page .= List_Paths($gene);

  return $pathway_page;
}

######################################################################
sub GetPathwaysByKeyword_1 {
  my ($base, $key) = @_;

  my $test = Scan ($base, $key);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  $BASE = $base;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to database\n";
    return "";
  }

  my ($pathway_page, $path_id);
  my ($pathway_name, $pathway_display);
  my ($first, $no_h, $no_m, $pnum, $pair);
  my (%paths, %m_paths);

  my $ukey = uc $key;
  $ukey =~ s/\*/%/g;
  $ukey =~ s/^/%/ if ($ukey !~ /^%/);
  $ukey =~ s/$/%/ if ($ukey !~ /%$/);

  my $sql_pathway = "select distinct p.pathway_name, p.pathway_display " .
                    "from $CGAP_SCHEMA.BioPaths p " .
                    "where upper(p.pathway_display) like '$ukey' " .
                    "or    upper(p.pathway_name) like '$ukey' " .
                    "order by upper(p.pathway_display)";

  my $stm = $db->prepare($sql_pathway);

  if (!$stm->execute()) {
     ## print STDERR "$sql_pathway\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     return "";
  }

  $stm->bind_columns(\$pathway_name, \$pathway_display);

  $pathway_page = "<TR><TH align=left>BioCarta Pathways</TH></TR>";
  $pathway_page .= "<TR><TD valign=top align=left><UL>";
  $first = 0; $pnum = 0;
  while ($stm->fetch) {
    if ($pathway_display) {
      if ($pathway_name =~ /^h_/) {
        $no_h = substr($pathway_name,2);
        $paths{$pnum++} = $no_h . ',' . $pathway_display;
      } elsif ($pathway_name =~ /^m_/) {
        $no_m = substr($pathway_name,2);
        $m_paths{$no_m} = 1;
      }
    }
  }
  foreach $pnum (sort numerically keys %paths) {
    ($pathway_name,$pathway_display) = split ',', $paths{$pnum};
    $first = 1;
    $pathway_page .= 
    "<LI><A class=genesrch href=\"" . $BASE .
    "/Pathways/BioCarta/h_$pathway_name\">" . $pathway_display . "</A> " .
    "<A href=\"" . $BASE . "/Pathways/BioCarta/h_$pathway_name\"> " .
    "<IMG SRC=\"" . IMG_DIR . "/BioCarta/buttonH.gif\" alt=\"buttonH\" border=0 title=\"Human Pathway\"></A> " ;
    if ($m_paths{$pathway_name}) {
      $pathway_page .= 
      "<A class=genesrch href=\"" . $BASE .
      "/Pathways/BioCarta/m_$pathway_name\">" .
      "<IMG SRC=\"" . IMG_DIR . "/BioCarta/buttonM.gif\" alt=\"buttonM\" border=0 title=\"Mouse Pathway\"></A>";
    }
  }
  $stm->finish;
  if (not $first) {
    $pathway_page .= "<LI><B>No Pathways Found</B>";
  }
  $pathway_page .=  "</UL></TD></TR>\n";

  ## my $sql_pathway = "select distinct p.path_id, p.pathway_name " .
  ##                   "from $CGAP_SCHEMA.KeggPathNames p " .
  ##                   "where upper(p.pathway_name) like '$ukey' " .
  ##                   "or    upper(p.path_id) like '$ukey' " .
  ##                   "order by upper(p.pathway_name)";

  ## my $stm = $db->prepare($sql_pathway);

  ## if (!$stm->execute()) {
     ## print STDERR "$sql_pathway\n";
     ## print STDERR "$DBI::errstr\n";
  ##    print "execute call failed\n";
  ##    return "";
  ## }

  ## $stm->bind_columns(\$path_id, \$pathway_name);

  ## $pathway_page .= "<TR><TH align=left>KEGG Pathways</TH></TR>";
  ## $pathway_page .= "<TR><TD valign=top align=left><UL>";
  ## $first = 0;
  ## while ($stm->fetch) {
  ##   if ($pathway_name) {
  ##     $first = 1;
  ##     $pathway_page .= 
  ##       "<LI><A class=genesrch href=\"" . $BASE .
  ##       "/Pathways/Kegg/$path_id\">" .
  ##       $pathway_name . "</A>\n";
  ##   }
  ## }
  ## $stm->finish;
  ## if (not $first) {
  ##   $pathway_page .= "<LI><B>No Pathways Found</B>";
  ## }
  ## $pathway_page .=  "</UL></TD></TR>\n";

  $db->disconnect();

  return $pathway_page;
}

######################################################################
1;
