######################################################################
# Paging.pm
#
#
######################################################################

use constant ITEMS_PER_PAGE    => 300;
use constant ROWS_PER_SUBTABLE => 100;

######################################################################
sub PageGeneList {
  my ($BASE, $page, $org, $page_header, $table_header,
      $action, $form_name, $hidden_names, $hidden_vals,
      $formatter_ref, $items_ref) = @_;

  ##
  ## the $formatter_ref function expects a $what=="HTML" param
  ##

  my (@lines);

  push @lines, "<table width='100%' cellspacing=0 cellpadding=0>";
  push @lines, "<tr valign=top>" ;
  push @lines, "<td width='65%'>" ;
  push @lines, "$page_header" ;
  push @lines, "</td>" ;
  push @lines, "<td rowspan=2 valign=center align=center>" ;
## Comment out below to run UN-Common ##
  push @lines, "<div id='restriction' style='position:relative; visibility:visible; color:#38639d; background-color:#fff5ee; font-family:monotype corsiva, garamond, verdana; font-weight:bold; width:130; height:65;'>Highlight common aspects of the listed genes</div>" ;
  push @lines, "</td>" ;
  push @lines, "<td rowspan=2 align=center><form name='commonform' action='CommonView' method=post>";
  push @lines, "<input type=hidden name=PAGE value=" . $page . ">" ;
  my $head = 0;
  for (my $h=0; $h < @{ $hidden_names }; $h++) {
    push @lines, "<input type=hidden name=$$hidden_names[$h] value=\"$$hidden_vals[$h]\">" if ($$hidden_names[$h] ne "");
    $head = 1 if ($$hidden_names[$h] eq "PAGE_HEADER");
  }
  push @lines, "<input type=hidden name=PAGE_HEADER value=\"" . "$page_header" . "\">"  if ($head == 0);
  push @lines, "<table border=5 bordercolor='#38639d' cellpadding=1 cellspacing=1 bgcolor='#ffffff' style='color:#38639d;'>" ;
  push @lines, "<tr><th style='font-size:8pt; font-weight:bold;' nowrap>" ;
  push @lines, "Common View" ;
  push @lines, "</th></tr>" ;
  push @lines, "<tr align='left'><th style='font-size:8pt; font-weight:bold;' nowrap>";
  push @lines, "<input type='checkbox' name='CKBOX' value='0' onClick='javascript:checkBoxValidate(0)'>Cyt Loc<br>" ;
  push @lines, "<input type='checkbox' name='CKBOX' value='1' onClick='javascript:checkBoxValidate(1)'>Pathways<br>" ;
  push @lines, "<input type='checkbox' name='CKBOX' value='2' onClick='javascript:checkBoxValidate(2)'>Ontology<br>" ;
##push @lines, "<input type='checkbox' name='CKBOX' value='3' onClick='javascript:checkBoxValidate(3)'>Tissues<br>" ;
  push @lines, "<input type='checkbox' name='CKBOX' value='4' onClick='javascript:checkBoxValidate(4)'>Motifs<br>" ;
  push @lines, "<input type='checkbox' name='CKBOX' value='5' onClick='javascript:checkBoxValidate(5)'>SNPs<br>" ;
  push @lines, "</th>" ;
  push @lines, "</tr>" ;
  push @lines, "<tr><td align=center>" ;
  push @lines, "<a href=\"javascript:document.commonform.submit()\"><img src=\"" . IMG_DIR . "/Common/view.gif\" alt=\"View\" border=0></a>" ;
  push @lines, "</td></tr>" ;
  push @lines, "</table></form>" ;

## Comment out above to run UN-Common ##
  push @lines, "</td>" ;
  push @lines, "</tr>" ;

  my $num_pages = int(scalar(@{ $items_ref }) / ITEMS_PER_PAGE);
  if (int(scalar(@{ $items_ref }) % ITEMS_PER_PAGE)) {
    $num_pages++;
  }

  push @lines, "<TR><TD>";
  push @lines, "<form name=$form_name  method=post>";
  for (my $h =0; $h < @{ $hidden_names }; $h++) {
    push @lines, "<input type=hidden name=$$hidden_names[$h] " .
        "value=\"$$hidden_vals[$h]\">" if ($$hidden_names[$h] ne "");
  }

  ## for microarray stuff
  push @lines, "<input type=hidden name=SHOW value=1>";
  push @lines, "<input type=hidden name=SRC>";

  push @lines, "<table cellpadding=4><tr>";
  push @lines, "<td>" .
      "<a href=\"javascript:" .
      "document.$form_name.action='$action';" .
      ($num_pages > 25 ?
          ("document.$form_name.PAGE." .
          "options[document.$form_name.PAGE.selectedIndex].value=0;") :
          ("document.$form_name.PAGE.value=0;")
      ) .
      "document.$form_name.submit()\">".
      "<b>[Text]</b></a></td>";
  push @lines, "<td><a href=\"javascript:" .
      "document.$form_name.action='$action';" .
      ($num_pages > 25 ?
          ("document.$form_name.PAGE." .
          "options[document.$form_name.PAGE.selectedIndex].value=1000000;") :
          ("document.$form_name.PAGE.value=1000000;")
      ) .
      "document.$form_name.submit()\">" .
      "<b>[Clones]</b></a></td>";
  if ($org eq "Hs") {
    push @lines, "<td><a href=\"javascript:" .
        "document.$form_name.action='$BASE/Microarray/GeneList';" .
        "document.$form_name.SRC.value='NCI60';" .
        "document.$form_name.submit()\">" .
        "<b>[NCI60]</b></a></td>";
    push @lines, "<td><a href=\"javascript:" .
        "document.$form_name.action='$BASE/Microarray/GeneList';" .
        "document.$form_name.SRC.value='SAGE';" .
        "document.$form_name.submit()\">" .
        "<b>[SAGE]</b></a></td>";
  }
  push @lines, "</tr></table>";

  my ($i, $j);
  ## $i..$j will be, e.g., 0..n-1, n..2n-1, ...
  $i = ($page - 1) * ITEMS_PER_PAGE;
  $j = $i + ITEMS_PER_PAGE - 1;
  if ($j + 1 > scalar(@{ $items_ref })) {
    ## Set $j = index of last item
    $j = scalar(@{ $items_ref }) - 1;
  }

  push @lines, "<p><b>Displaying " .
      ($i+1) . " thru " . ($j+1) . " of " . scalar(@{ $items_ref }) .
      " items</b>";

  if ($num_pages > 25) {

    push @lines, "<p><a href=\"javascript:" .
        "document.$form_name.action='$action';" .
        "document.$form_name.submit()\">" .
        "<b>Go to page</b></a>&nbsp;";
    push @lines, "<select name=PAGE>";
    for (my $p = 1; $p <= $num_pages; $p++) {
      push @lines, "<option value=$p" .
          ($page == $p ? " selected" : "") .
          ">$p</option>";
    }
    push @lines, "</select>&nbsp;&nbsp";

  } elsif ($num_pages > 1) {

    push @lines, "<input type=hidden name=PAGE>";
    push @lines, "<p><b>Go to page:";
    for (my $a = 1; $a <= $num_pages; $a++) {
      if ($a == $page) {
        push @lines, "<b>$a</b>";
      } else {
        push @lines, "<a href=\"javascript:" .
            "document.$form_name.action='$action';" .
            "document.$form_name.PAGE.value=$a;" .
            "document.$form_name.submit()\">".
            "<b>$a</b></a>";
      }  
    } 
  
  } else {

    push @lines, "<input type=hidden name=PAGE>";

  }

  push @lines, "</form>";
  push @lines, "</td></tr>";
  push @lines, "</table>";
  push @lines, $table_header;

  my $k;
  my $row_count = 0;
  for ($k = 0; $i <= $j; $i++, $k++) {
    push @lines, &{ $formatter_ref }("HTML", $org, $$items_ref[$i]);
    if (++$row_count % ROWS_PER_SUBTABLE == 0 and $i < $j) {
      push @lines, "</table>\n$table_header";
    }
  }

  push @lines, "</table>";

  return join("\n", @lines);
}

######################################################################
sub PageCommonGeneList {
  my ($BASE, $page, $org, $page_header, $table_header,
      $action, $form_name, $hidden_names, $hidden_vals,
      $page_ref, $scroller_ref, $items_ref) = @_;

  my (@lines);

  my $ckbox = $$hidden_vals[0];

  push @lines, "<table width='100%' cellspacing=0 cellpadding=0>" ;
  push @lines, "<tr valign=top>" ;
  push @lines, "<td width='65%'>" ;
  push @lines, "$page_header" ;
  push @lines, "</td>" ;
  push @lines, "<td rowspan=2 valign=center align=center>" ;
  push @lines, "<div id='restriction' style='position:relative; visibility:visible; color:#38639d; background-color:#fff5ee; font-family:monotype corsiva, garamond, verdana; font-weight:bold; width:130; height:65;'>Highlight common aspects of the listed genes</div>" ;
  push @lines, "</td>" ;
  push @lines, "<td rowspan=2 align=center><form name='commonform' action='CommonView' method=post>";
  push @lines, "<input type=hidden name=PAGE value=" . $page . ">" ;
  push @lines, "<input type=hidden name=ORG value=" . $org . ">" ;
  push @lines, "<input type=hidden name=PAGE_HEADER value=\"" . "$page_header" . "\">" ;
  for (my $h=1; $h < @{ $hidden_names }; $h++) {
    push @lines, "<input type=hidden name=$$hidden_names[$h] value=\"$$hidden_vals[$h]\">" if ($$hidden_names[$h] ne "");
  }
  push @lines, "<table border=5 bordercolor='#38639d' cellpadding=1 cellspacing=1 bgcolor='#ffffff' style='color:#38639d;'>" ;
  push @lines, "<tr><th style='font-size:8pt; font-weight:bold;' nowrap>" ;
  push @lines, "Common View" ;
  push @lines, "</th></tr>" ;
  push @lines, "<tr align='left'><th style='font-size:8pt; font-weight:bold;' nowrap>";
  push @lines, "<input type='checkbox' name='CKBOX' value='0' onClick='javascript:checkBoxValidate(0)'" . (($ckbox =~ /0/) ? "CHECKED" : "") . ">Cyt Loc<br>" ;
  push @lines, "<input type='checkbox' name='CKBOX' value='1' onClick='javascript:checkBoxValidate(1)'" . (($ckbox =~ /1/) ? "CHECKED" : "") . ">Pathways<br>" ;
  push @lines, "<input type='checkbox' name='CKBOX' value='2' onClick='javascript:checkBoxValidate(2)'" . (($ckbox =~ /2/) ? "CHECKED" : "") . ">Ontology<br>" ;
##push @lines, "<input type='checkbox' name='CKBOX' value='3' onClick='javascript:checkBoxValidate(3)'" . (($ckbox =~ /3/) ? "CHECKED" : "") . ">Tissues<br>" ;
  push @lines, "<input type='checkbox' name='CKBOX' value='4' onClick='javascript:checkBoxValidate(4)'" . (($ckbox =~ /4/) ? "CHECKED" : "") . ">Motifs<br>" ;
  push @lines, "<input type='checkbox' name='CKBOX' value='5' onClick='javascript:checkBoxValidate(5)'" . (($ckbox =~ /5/) ? "CHECKED" : "") . ">SNPs<br>" ;
  push @lines, "</th>" ;
  push @lines, "</tr>" ;
  push @lines, "<tr><td align=center>" ;
  push @lines, "<a href=\"javascript:document.commonform.submit()\"><img src=\"" . IMG_DIR . "/Common/view.gif\" alt=\"View\" border=0></a>" ;
  push @lines, "</td></tr>" ;
  push @lines, "</table></form>" ;
  push @lines, "</td>" ;
  push @lines, "</tr>" ;

  my $num_pages = int(scalar(@{ $items_ref }) / ITEMS_PER_PAGE);
  if (int(scalar(@{ $items_ref }) % ITEMS_PER_PAGE)) {
    $num_pages++;
  }

  push @lines, "<TR><TD>";
  push @lines, "<form name=$form_name  method=post>";
  for (my $h=0; $h < @{ $hidden_names }; $h++) {
    push @lines, "<input type=hidden name=$$hidden_names[$h] " .
        "value=\"$$hidden_vals[$h]\">" if ($$hidden_names[$h] ne "");
  }

  ## for microarray stuff
  push @lines, "<input type=hidden name=SHOW value=1>";
  push @lines, "<input type=hidden name=SRC>";
  ## for commongene stuff
  push @lines, "<input type=hidden name=ORG value=$org>";
  push @lines, "<input type=hidden name=PAGE_HEADER value=\"$page_header\">";

  push @lines, "<table cellpadding=4><tr>";
  push @lines, "<td>" .
      "<a href=\"javascript:" .
      "document.$form_name.action='$action';" .
      ($num_pages > 25 ?
          ("document.$form_name.PAGE." .
          "options[document.$form_name.PAGE.selectedIndex].value=0;") :
          ("document.$form_name.PAGE.value=0;")
      ) .
      "document.$form_name.submit()\">".
      "<b>[Text]</b></a></td>";
  push @lines, "<td><a href=\"javascript:" .
      "document.$form_name.action='$action';" .
      ($num_pages > 25 ?
          ("document.$form_name.PAGE." .
          "options[document.$form_name.PAGE.selectedIndex].value=1000000;") :
          ("document.$form_name.PAGE.value=1000000;")
      ) .
      "document.$form_name.submit()\">" .
      "<b>[Clones]</b></a></td>";
  if ($org eq "Hs") {
    push @lines, "<td><a href=\"javascript:" .
        "document.$form_name.action='$BASE/Microarray/GeneList';" .
        "document.$form_name.SRC.value='NCI60';" .
        "document.$form_name.submit()\">" .
        "<b>[NCI60]</b></a></td>";
    push @lines, "<td><a href=\"javascript:" .
        "document.$form_name.action='$BASE/Microarray/GeneList';" .
        "document.$form_name.SRC.value='SAGE';" .
        "document.$form_name.submit()\">" .
        "<b>[SAGE]</b></a></td>";
  }
  push @lines, "</tr></table>";

  my ($i, $j);
  ## $i..$j will be, e.g., 0..n-1, n..2n-1, ...
  $i = ($page - 1) * ITEMS_PER_PAGE;
  $j = $i + ITEMS_PER_PAGE - 1;
  if ($j + 1 > scalar(@{ $items_ref })) {
    ## Set $j = index of last item
    $j = scalar(@{ $items_ref }) - 1;
  }

  push @lines, "<p><b>Displaying " .
      ($i+1) . " thru " . ($j+1) . " of " . scalar(@{ $items_ref }) .
      " items</b>";

  if ($num_pages > 25) {

    push @lines, "<p><a href=\"javascript:" .
        "document.$form_name.action='$action';" .
        "document.$form_name.submit()\">" .
        "<b>Go to page</b></a>&nbsp;";
    push @lines, "<select name=PAGE>";
    for (my $p = 1 ; $p <= $num_pages ; $p++) {
      push @lines, "<option value=$p" .
          ($page == $p ? " selected" : "") .
          ">$p</option>";
    }
    push @lines, "</select>&nbsp;&nbsp";

  } elsif ($num_pages > 1) {

    push @lines, "<input type=hidden name=PAGE>";
    push @lines, "<p><b>Go to page:";
    for (my $a = 1 ; $a <= $num_pages ; $a++) {
      if ($a == $page) {
        push @lines, "<b>$a</b>";
      } else {
        push @lines, "<a href=\"javascript:" .
            "document.$form_name.action='$action';" .
            "document.$form_name.PAGE.value=$a;" .
            "document.$form_name.submit()\">".
            "<b>$a</b></a>";
      }  
    } 
  
  } else {

    push @lines, "<input type=hidden name=PAGE>";

  }

  push @lines, "</form>";
  push @lines, "</td></tr>";
  push @lines, "</table>";
  push @lines, $table_header;

  for (my $p = 0 ; $p < @{ $page_ref } ; $p++) {
    push @lines, "$$page_ref[$p]";
  }

  push @lines, "</table>";
  push @lines, "<script>";
  for (my $s = 0 ; $s < @{ $scroller_ref } ; $s++) {
    push @lines, "$$scroller_ref[$s]";
  }
  push @lines, "</script>";

  return join("\n", @lines);
}


######################################################################
sub PageResults {
  my ($page, $org, $cmd, $page_header, $table_header,
      $formatter_ref, $items_ref) = @_;

  ##
  ## the $formatter_ref function expects a $what=="HTML" param
  ##

  my $num_pages = int(scalar(@{ $items_ref }) / ITEMS_PER_PAGE);
  if (int(scalar(@{ $items_ref }) % ITEMS_PER_PAGE)) {
    $num_pages++;
  }

  my $form_name = "";
  if ($cmd =~ /(javascript:)(.*)(document\.)([^\.]+)(\.submit\(\))$/i) {
    $form_name = $4;
    $by_form = 1;
  } else {
    $form_name = "pform";
    $by_form = 0;
  }

  ## $by_form == True means that somewhere else, the html for a
  ## surrounding form is being generated. We have found out the
  ## name of this surrounding form from the $cmd

  my $s = "";
  if (not $by_form) {
##    $s = "<form name=$form_name action=\"" . BASE .
    $s = "<form name=$form_name action=\"" .
        (split /\?/, $cmd)[0] . "\">";
    my ($inp_name, $inp_val);
    for my $input (split "&", ((split /\?/, $cmd)[1])) {
      ($inp_name, $inp_val) = split "=", $input;
      if ($inp_name !~ /^PAGE$/) {
        $s = $s .
            "<input type=hidden name=$inp_name value=\"$inp_val\">\n";
      }
    }
  }

  if ($num_pages > 25) {
    $s = $s . "<table width=600><tr><td><a href=\"javascript:document." .
        "$form_name.submit()\">" .
        "<b>Go to page</b></a>&nbsp;";
    $s = $s . "<select name=PAGE>\n";
    for (my $p = 1; $p <= $num_pages; $p++) {
      $s = $s . "<option value=$p" .
          ($page == $p ? " selected" : "") .
          ">$p</option>\n"
    }
    $s = $s . "</select>&nbsp;&nbsp; or &nbsp;&nbsp;\n";
    $s = $s . "<a href=\"javascript:document.$form_name.PAGE." .
        "options[document.$form_name.PAGE.selectedIndex].value=0;" .
        "document.$form_name.submit()\"><b>[Full Text]</b></a></td>" .
        "<td align=right>";
    if ($page != 1) { 
      $s = $s . "<a href=\"javascript:document.$form_name.PAGE." .
          "options[document.$form_name.PAGE.selectedIndex].value=" .
          ($page-1) . ";document.$form_name.submit()\">".
          "<img src=\"". IMG_DIR ."/PrevPage.gif\" alt=\"Previous_Page\" border=0></a>\n";
    }
    if ($page != $num_pages) {           
      $s = $s . "<a href=\"javascript:document.$form_name.PAGE." .
          "options[document.$form_name.PAGE.selectedIndex].value=" .
          ($page+1) . ";document.$form_name.submit()\">".
          "<img src=\"". IMG_DIR ."/NextPage.gif\" alt=\"Next_Page\" border=0></a>\n";
    }  
    $s = $s . "</td></tr>\n";
  } elsif ($num_pages > 1) {
    $s = $s . "<input type=hidden name=PAGE>\n";
    $s = $s . "<table width=600><tr><td align=left><b>Go to page:\n";
    for (my $a = 1; $a <= $num_pages; $a++) {
      if ($a == $page) {
        $s = $s . "<b>$a</b>\n  ";
      } else {
        $s = $s . "<a href=\"javascript:document.$form_name.PAGE.value=$a" .
            ";document.$form_name.submit()\">".
            "<b>$a</b></a>\n";
      }  
    } 
    $s = $s . "<a href=\"javascript:document.$form_name.PAGE.value=0" .
        ";document.$form_name.submit()\">".
        "<b>[Full Text]</b></a></td>\n" .
        "<td align=right>";
    if ($page != 1) { 
      $s = $s . "<a href=\"javascript:document.$form_name.PAGE.value=" .
          ($page-1) . ";document.$form_name.submit()\">".
          "<img src=\"". IMG_DIR ."/PrevPage.gif\" alt=\"Previous_Page\" border=0></a>\n";
    }
    if ($page != $num_pages) {           
      $s = $s . "<a href=\"javascript:document.$form_name.PAGE.value=" .
          ($page+1) . ";document.$form_name.submit()\">".
          "<img src=\"". IMG_DIR ."/NextPage.gif\" alt=\"Next_Page\" border=0></a>\n";
    }  
    $s = $s . "</td></tr>\n";  
  } else {
    $s = $s . "<input type=hidden name=PAGE>\n";
    $s = $s . 
        "<table width=600><tr><td colspan=2>" .
        "<td colspan=2><a href=\"javascript:" .
        "document.$form_name.PAGE.value=0;" .
        "document.$form_name.submit()\"" .
        "><b>[Full Text]</b></a></td>";
  }

  my ($i, $j);

  ##
  ## $i..$j will be, e.g., 0..n-1, n..2n-1, ...
  ##

  $i = ($page - 1) * ITEMS_PER_PAGE;
  $j = $i + ITEMS_PER_PAGE - 1;

  if ($j + 1 > scalar(@{ $items_ref })) {

    ##
    ## Set $j = index of last item
    ##

    $j = scalar(@{ $items_ref }) - 1;
  }


  $s = $s .
      "<tr><td colspan=2 align=left><b>Displaying " .
      ($i+1) . " thru " . ($j+1) . " of " . scalar(@{ $items_ref }) .
      " items</b></td></tr></table>";

  if (not $by_form) {
    $s = $s . "</form>\n";
  }

  $s = $s . $table_header;

  my $k;
  my @formatted_lines;
  my $row_count = 0;
##  $table_header =~ /(<table[^>]*>)/i;
##  my $table_tag = $1;
  for ($k = 0; $i <= $j; $i++, $k++) {
    $formatted_lines[$k] =
        "\n" . &{ $formatter_ref }("HTML", $org, $$items_ref[$i]);
    if (++$row_count % ROWS_PER_SUBTABLE == 0 and $i < $j) {
      $formatted_lines[$k] = $formatted_lines[$k] . "</table>\n$table_header";
    }
  }

  $s = "<h4>$page_header</h4>\n" . $s .
      (join("", @formatted_lines)) . '</table>';

  return $s;
}

######################################################################

1;

