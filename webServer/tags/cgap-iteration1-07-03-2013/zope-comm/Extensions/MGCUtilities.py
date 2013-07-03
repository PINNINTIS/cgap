#! /usr/local/bin/python

from CommonUtilities import *
import string
import commands

######################################################################
def CloneList (page_string, org, status, data_home, base):
  import re
  import string

#  ROWS_PER_PAGE = 300
  ROWS_PER_PAGE = 100
  fname = ""
  if (org == "Hs"):
    if (status == "Confirmed"):
      fname = data_home + "hs_con_mrna.data"
#    elif (status == "Putative"):
#      fname = data_home + "hs_put_mrna.data"
  elif (org == "Mm"):
    if (status == "Confirmed"):
      fname = data_home + "mm_con_mrna.data"
  elif (org == "Dr"):
    if (status == "Confirmed"):
      fname = data_home + "dr_con_mrna.data"
  elif (org == "Xl"):
    if (status == "Confirmed"):
      fname = data_home + "xl_con_mrna.data"
##  elif (org == "Str"):
  elif (org == "Xt"):
    if (status == "Confirmed"):
      fname = data_home + "str_con_mrna.data"
  elif (org == "Rn"):
    if (status == "Confirmed"):
      fname = data_home + "rn_con_mrna.data"
  elif (org == "Bt"):
    if (status == "Confirmed"):
      fname = data_home + "bt_con_mrna.data"
#    elif (status == "Putative"):
#      fname = data_home + "mm_put_mrna.data"

  if (fname == ""):
    return "No clone data for " + org + ", " + status

  page = int(page_string)

  f = open (fname, "r")
  lines = f.readlines()
  f.close()

  total_rows = len(lines)
  number_of_pages = total_rows/ROWS_PER_PAGE
  if (total_rows % ROWS_PER_PAGE != 0):
    number_of_pages = number_of_pages + 1

  if (page == 0):
    table_header = \
        "Symbol\t" + \
        "GenBank defline\t" + \
        "LocusLink ID\t" + \
        "UniGene cluster\t" + \
        "IMAGE ID\t" + \
        "GenBank accession\t" + \
        "Clone Length\t" + \
        "Library ID\t" + \
        "Library name\t" + \
        "\n"
  else:
    cmd = \
        "Displaying page " + page_string + " of " + \
        str(number_of_pages) + "<br>\n" + \
        "<form name=pform action=\"" + base + "/Reagents/StaticCloneList\">" + \
        "<input type=hidden name=ORG value=" + org + ">" + \
        "<input type=hidden name=STATUS value=" + status + ">" + \
        "<a href=\"javascript:document.pform.submit()\">Go to page</a>&nbsp" + \
        "<select name=PAGE>"
    for p in range(1, number_of_pages + 1):
      if p == page:
        cmd = cmd + "<option value=" + str(p) + " selected>" + str(p) + "</option>"
      else:
        cmd = cmd + "<option value=" + str(p) + ">" + str(p) + "</option>"
    cmd = cmd + "</select>"
    if page > 1:
      cmd = cmd + "&nbsp&nbsp&nbsp"
      cmd = cmd + "<a href=\"" + base + "/Reagents/StaticCloneList?PAGE=" + \
          str(page-1) + "&ORG=" + \
          org + "&STATUS=" + status + "\">[Previous]</a>"
    if page < number_of_pages:
      cmd = cmd + "&nbsp&nbsp&nbsp"
      cmd = cmd + "<a href=\"" + base + "/Reagents/StaticCloneList?PAGE=" + \
          str(page+1) + "&ORG=" + \
          org + "&STATUS=" + status + "\">[Next]</a>"
    cmd = cmd + "&nbsp&nbsp&nbsp"
    cmd = cmd + "<a href=\"" + base + "/Reagents/StaticCloneList?PAGE=0&ORG=" + \
        org + "&STATUS=" + status + "\">[Full Text Listing]</a></form>"

    table_header = "<table border=1 cellspacing=1 cellpadding=4>" + \
        "<tr bgcolor=\"#666699\">" + \
        "<td><font color=\"white\"><b>Symbol</b></font></td>" + \
        "<td><font color=\"white\"><b>GenBank Def</b></font></td>" + \
        "<td><font color=\"white\"><b>IMAGE ID</b></font></td>" + \
        "<td><font color=\"white\"><b>GenBank Accession</b></font></td>" + \
        "<td><font color=\"white\"><b>Clone Length</b></font></td>" + \
        "<td><font color=\"white\"><b>Library</b></font></td>" + \
        "</tr>\n"

  rows = []
  if (page != 0):
    rows.append(cmd)
  rows.append(table_header)

  if (page == 0):
    lo = 0
    hi = total_rows
  else:
    lo = (page-1)*ROWS_PER_PAGE
    hi = lo + ROWS_PER_PAGE
    if (hi > total_rows):
      hi = total_rows
  for i in range(lo, hi):
    [image, lid, library, acc, leng, ug, ll, sym, gb] = \
        re.split("\t", lines[i][:-1])
    if (page == 0):
      rows.append(\
          string.join([sym, gb, ll,  org + "." + ug, \
          "IMAGE:" + image, acc, leng, lid, library], "\t") \
          + "\n")
    else:
      if (acc == ""):
        acc = "&nbsp;"
      else:
        acc = "<a href=\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" + \
              "db=Nucleotide&CMD=Search&term=" + acc + "\">" + \
              acc + "</a>"
      if (leng == ""):
        leng = "&nbsp;"
      if (ug == ""):
        ug = "&nbsp;"
      else:
        ug = org + " . " + ug
      if (ll == ""):
        sym = "&nbsp;"
      else:
        if (sym == ""):
          sym = "<a href=javascript:spawn(\"http://www.ncbi.nlm.nih.gov/" + \
                "LocusLink/LocRpt.cgi?l=" + ll + "\")>[no symbol]</a>"
        else:
          sym = "<a href=javascript:spawn(\"http://www.ncbi.nlm.nih.gov/" + \
                "LocusLink/LocRpt.cgi?l=" + ll + "\")>" + sym + "</a>"
      if (gb == ""):
        gb = "&nbsp;"
      row = \
         "<tr>" + \
         "<td>" + sym + "</td>\n" + \
         "<td>" + gb + "</td>" + \
         "<td><a href=\"" + base + "/Reagents/CloneInfo?" + \
              "ORG=" + org + "&IMAGE=" + image + \
              "\">" + image + "</a></td>\n" + \
         "<td>" + acc + "</td>\n" + \
         "<td>" + leng + "</td>\n" + \
         "<td><a href=\"" + base + "/Tissues/LibInfo?" + \
              "ORG=" + org + "&LID=" + lid + \
              "\">" + library + "</a></td>\n" + \
         "</tr>\n"
      rows.append(row)
      if ((i + 1 < hi) and ((i + 1) % 100 == 0)):
        rows.append("</table>" + table_header)
  if (page != 0):
    rows.append("</table>")
  return string.join(rows, "")

######################################################################
