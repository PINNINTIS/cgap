#! /usr/bin/python

from CommonUtilities import *
import commands

MITO_ACC = "X93334"

######################################################################
def GetStats (binpath, format, what, rank):

  cmd = binpath + "/" + "GetStats.pl" + \
      " " + format + \
      " " + what   + \
      " " + rank

  (status,response) = commands.getstatusoutput(cmd)
  return response

######################################################################
def FindLibsForSDGED (base, sagecgi, request):
  import string
  import re
  import tempfile

 ## org = "Hs"

  seqs          = GetRequestParam(request, 'SEQS')
  sort          = GetRequestParam(request, 'SORT')
  title_a       = GetRequestParam(request, 'TITLE_A')
  tissue_a      = GetRequestParam(request, 'TISSUE_A')
  hist_a        = GetRequestParam(request, 'HIST_A')
  comp_a        = GetRequestParam(request, 'COMP_A')
  cell_a        = GetRequestParam(request, 'CELL_A')
  lib_a         = GetRequestParam(request, 'LIB_A')
  stage_a       = GetRequestParam(request, 'STAGE_A')
  comp_stage_a  = GetRequestParam(request, 'COMP_STAGE_A')
  user_file_a   = GetRequestParam(request, 'USER_FILE_A')
  filehandle_a  = request.form['USER_DATA_A']
  title_b       = GetRequestParam(request, 'TITLE_B')
  tissue_b      = GetRequestParam(request, 'TISSUE_B')
  hist_b        = GetRequestParam(request, 'HIST_B')
  comp_b        = GetRequestParam(request, 'COMP_B')
  cell_b        = GetRequestParam(request, 'CELL_B')
  lib_b         = GetRequestParam(request, 'LIB_B')
  stage_b       = GetRequestParam(request, 'STAGE_B')
  comp_stage_b  = GetRequestParam(request, 'COMP_STAGE_B')
  user_file_b   = GetRequestParam(request, 'USER_FILE_B')
  filehandle_b  = request.form['USER_DATA_B']
  what          = GetRequestParam(request, 'WHAT')
  save          = GetRequestParam(request, 'SAVE')
  org           = GetRequestParam(request, 'ORG')
  method        = GetRequestParam(request, 'METHOD')

  lists = 'seqs' + sort
  scan = Scan(lists)
 
  if (scan != ""):
    return '8888'


  a_set = []
  b_set = []
  if save == 'yes':
    for k in request.form.keys():
      if (k[0:2] == 'A_'):
        a_set.append(k)
      elif (k[0:2] == 'B_'):
        b_set.append(k)

  if ( user_file_b == "" and user_file_a == ""):
    if( tissue_a == "" and lib_a == "" and a_set == "" ) :
      return "<br><br><center><b>Error: Please choose Pool A<b><br>" 
    if(  tissue_b == "" and lib_b == "" and lib_a == "" and b_set == "" ) :
      return "<br><br><center><b>Error: Please choose Pool B<b><br>" 
  if ( user_file_a and user_file_b == "" and lib_b == "" and b_set == "" ):
    return "<br><br><center><b>Error: Please choose Pool B<b><br>" 
  if ( user_file_b and tissue_a == "" and user_file_a == "" and lib_a == "" and a_aet == "" ):
    return "<br><br><center><b>Error: Please choose Pool A<b><br>" 
  if ( tissue_a and tissue_b == "" and user_file_b == "" and lib_b == "" and b_set == "" ):
    return "<br><br><center><b>Error: Please choose Pool B<b><br>" 
  if ( tissue_b and tissue_a == "" and user_file_a == "" and lib_a == "" and a_set == "" ):
    return "<br><br><center><b>Error: Please choose Pool A<b><br>" 

  tmpfn = tempfile.mktemp()
  tmpf = open(tmpfn, "w")
  tmpf.write(seqs     + "\n")
  tmpf.write(sort     + "\n")
  tmpf.write(title_a  + "\n")
  tmpf.write(tissue_a + "\n")
  tmpf.write(hist_a   + "\n")
  tmpf.write(comp_a   + "\n")
  tmpf.write(cell_a   + "\n")
  tmpf.write(lib_a    + "\n")
  tmpf.write(stage_a  + "\n")
  tmpf.write(comp_stage_a  + "\n")
  tmpf.write(user_file_a   + "\n")
  tmpf.write(title_b  + "\n")
  tmpf.write(tissue_b + "\n")
  tmpf.write(hist_b   + "\n")
  tmpf.write(comp_b   + "\n")
  tmpf.write(cell_b   + "\n")
  tmpf.write(lib_b    + "\n")
  tmpf.write(stage_b  + "\n")
  tmpf.write(comp_stage_b  + "\n")
  tmpf.write(user_file_b   + "\n")
  tmpf.write(org      + "\n")
  tmpf.write(method   + "\n")
  tmpf.close()

  tmpfn_a = ''
  tmpfn_b = ''
  if (filehandle_b):
    filedata = str(filehandle_b.read())
    tmpfn_b = tempfile.mktemp()
    tmpf = open(tmpfn_b, "w")
    tmpf.write(filedata)
    tmpf.close()

    if (filehandle_a):
      filedata = str(filehandle_a.read())

      tmpfn_a = tempfile.mktemp()
      tmpf = open(tmpfn_a, "w")
      tmpf.write(filedata)
      tmpf.close()

  response = BackEnd('',0,sagecgi,base,'SDGEDLibrarySelect.pl','',"'TMP_FILE','USER_FILE_A','USER_FILE_B'",request,{'TMP_FILE':tmpfn,'USER_FILE_A':tmpfn_a,'USER_FILE_B':tmpfn_b})

  if (response == ""):
    return "<br><br>There are no libraries matching the query<br>"

  if (response == "<br><b><center>Error in input: $input</b>!</center>"):
    return "<br><b><center>Error in input: $input</b>!</center>"


  (response_list, sdged_cache_id) = re.split("\003", response)

  ## if (filehandle_b):
  ##   local_cache_id = MakeRequest(host, port, 'MoveUploadFileToLocal(' + \
  ##     "'" + str(sdged_cache)        + "'  "   + \
  ##     ')')
  ##   sdged_cache = local_cache_id

  ## (sdged_cache, host_name) = re.split("HOSTNAME", sdged_cache_id)
  hidden = ""
  if (user_file_b):
    (sdged_cache, host_name) = re.split("HOSTNAME", sdged_cache_id)
    hidden = '<input type=hidden name="SDGED_CACHE" value=' + sdged_cache + '>'

  lines = []
  if (hidden):
    lines.append(hidden)

  lines.append(GetHiddensForSDGED(request))
  lib_header = "Library Name"
  if (user_file_b):
    if (user_file_a):
      lib_header = "File Name"
    else:
      lib_header = "Library/File Name"

  table_header = \
    "<table border=1 cellspacing=1 cellpadding=4>" + \
    "<tr bgcolor=\"#38639d\" valign=top>" + \
    "<td colspan=2><font color=\"white\"><b>Pool</b></font></td>" + \
    "<td rowspan=2><font color=\"white\"><b>" + lib_header + "</b></font></td>" + \
    "<td rowspan=2><font color=\"white\"><b>Tags</b></font></td>" + \
    "<td rowspan=2><font color=\"white\"><b>Keywords</b></font></td>" + \
    "</tr>" + \
    "<tr bgcolor=\"#38639d\" valign=top>" + \
    "<td><font color=\"white\"><b>A</b></font></td>" + \
    "<td><font color=\"white\"><b>B</b></font></td>" + \
    "</tr>\n"

  lines.append("<br><br>");

  lines.append(table_header)

  lib_list = re.split("\001", response_list)
  row_num = 0
  lid_link = ""
  for i in lib_list:
    if (row_num % 300 == 0 and row_num > 0):
      lines.append("</table>")
      lines.append(table_header)
    row_num = row_num + 1
    (lid, setA, setB, lib_name, num_seqs, keywords) = re.split("\002", i)
    if save == 'yes':
      a_flag = 0
      for a_id in a_set:
        temp_a = "A_" + lid
        if( temp_a == a_id ):
          a_flag = 1
      if a_flag == 1:
        setA = " checked"
      else:
        setA = ""
      b_flag = 0
      for b_id in b_set:
        temp_b = "B_" + lid
        if( temp_b == b_id ):
          b_flag = 1
      if b_flag == 1:
        setB = " checked"
      else:
        setB = "" 
    else:
      if setA == "A":
        setA = " checked"
        if (user_file_a):
          setA = setA + " disabled"
          setB = setB + " disabled"
        if (user_file_b):
          setB = setB + " disabled"
      if setB == "B":
        setB = " checked"
        if (user_file_b):
          setA = setA + " disabled"
          setB = setB + " disabled"
    if num_seqs == "":
      num_seqs = "&nbsp;"
    if keywords == "":
      keywords = "&nbsp;"
    if lid == "":
      lid_link = lib_name
    else:
      lid_link = \
      "<a href=\"SAGELibInfo?ORG=" + org + \
      "&LID=" + lid + "\">" + lib_name + "</a>"
    line_A = ""
    line_B = ""
    if (re.search("disabled", setA) != None):
      if (re.search("checked", setA) != None):
        line_A = "<td><label for=\"A_" + lid_link + '"' + "></label><input type=checkbox name=A_" + lid + setA + " id=\"A_" + lid_link + '"' + "></td>"
        line_B = "<td><label for=\"B_" + lid + '"' + "></label><input type=checkbox name=B_" + lid + setB + " id=\"B_" + lid + '"' + "></td>"
      else:
        line_A = "<td><label for=\"A_" + lid + '"' + "></label><input type=checkbox name=A_" + lid + setA + " id=\"A_" + lid + '"' + "></td>"
        line_B = "<td><label for=\"B_" + lid_link + '"' + "></label><input type=checkbox name=B_" + lid + setB + " id=\"B_" + lid_link + '"' + "></td>"
    else:
      line_A = "<td><label for=\"A_" + lid + '"' + "></label><input type=checkbox name=A_" + lid + setA + " id=\"A_" + lid + '"' + "></td>"
      line_B = "<td><label for=\"B_" + lid + '"' + "></label><input type=checkbox name=B_" + lid + setB + " id=\"B_" + lid + '"' + "></td>"
    
    lines.append( \
      "<tr>" + \
      line_A + \
      line_B + \
      "<td>" + lid_link + "</td>" + \
      "<td>" + num_seqs + "</td>" + \
      "<td>" + keywords + "</td>" + \
      "</tr>" )
  lines.append("</table>")
  return string.join(lines, "\n")

######################################################################
def UncheckedLibsForSDGED (base, sagecgi, request):
  import string
  import re
  import tempfile

 ## org = "Mm"


  seqs          = GetRequestParam(request, 'SEQS')
  sort          = GetRequestParam(request, 'SORT')
  title_a       = GetRequestParam(request, 'TITLE_A')
  tissue_a      = GetRequestParam(request, 'TISSUE_A')
  hist_a        = GetRequestParam(request, 'HIST_A')
  comp_a        = GetRequestParam(request, 'COMP_A')
  cell_a        = GetRequestParam(request, 'CELL_A')
  lib_a         = GetRequestParam(request, 'LIB_A')
  stage_a       = GetRequestParam(request, 'STAGE_A')
  comp_stage_a  = GetRequestParam(request, 'COMP_STAGE_A')
  user_file_a   = GetRequestParam(request, 'USER_FILE_A')
  filehandle_a  = request.form['USER_DATA_A']
  title_b       = GetRequestParam(request, 'TITLE_B')
  tissue_b      = GetRequestParam(request, 'TISSUE_B')
  hist_b        = GetRequestParam(request, 'HIST_B')
  comp_b        = GetRequestParam(request, 'COMP_B')
  cell_b        = GetRequestParam(request, 'CELL_B')
  lib_b         = GetRequestParam(request, 'LIB_B')
  stage_b       = GetRequestParam(request, 'STAGE_B')
  comp_stage_b  = GetRequestParam(request, 'COMP_STAGE_B')
  user_file_b   = GetRequestParam(request, 'USER_FILE_B')
  filehandle_b  = request.form['USER_DATA_B']
  what          = GetRequestParam(request, 'WHAT')
  save          = GetRequestParam(request, 'SAVE')
  org           = GetRequestParam(request, 'ORG')
  method        = GetRequestParam(request, 'METHOD')

  a_set = []
  b_set = []
  if save == 'yes':
    for k in request.form.keys():
      if (k[0:2] == 'A_'):
        a_set.append(k)
      elif (k[0:2] == 'B_'):
        b_set.append(k)

  if ( user_file_b == "" and user_file_a == "" ):
    if(  tissue_a == "" and lib_a == "" and a_set == "" ) :
      return "<br><br><center><b>Error: Please choose Pool A<b><br>" 
    if( tissue_b == "" and lib_b == "" and lib_a == "" and b_set == "" ) :
      return "<br><br><center><b>Error: Please choose Pool B<b><br>" 
  if ( user_file_a and user_file_b == "" and lib_b == "" and b_set == "" ):
    return "<br><br><center><b>Error: Please choose Pool B<b><br>" 
  if ( user_file_b and tissue_a == "" and user_file_a == "" and lib_a == ""  and a_set == "" ):
    return "<br><br><center><b>Error: Please choose Pool A<b><br>" 
  if ( tissue_a and tissue_b == "" and user_file_b == "" and lib_b == "" and b_set == "" ):
    return "<br><br><center><b>Error: Please choose Pool B<b><br>" 
  if ( tissue_b and tissue_a == "" and user_file_a == "" and lib_a == "" and a_set == "" ):
    return "<br><br><center><b>Error: Please choose Pool A<b><br>" 

  tmpfn = tempfile.mktemp()
  tmpf = open(tmpfn, "w")
  tmpf.write(seqs     + "\n")
  tmpf.write(sort     + "\n")
  tmpf.write(title_a  + "\n")
  tmpf.write(tissue_a + "\n")
  tmpf.write(hist_a   + "\n")
  tmpf.write(comp_a   + "\n")
  tmpf.write(cell_a   + "\n")
  tmpf.write(lib_a    + "\n")
  tmpf.write(stage_a  + "\n")
  tmpf.write(comp_stage_a  + "\n")
  tmpf.write(user_file_a   + "\n")
  tmpf.write(title_b  + "\n")
  tmpf.write(tissue_b + "\n")
  tmpf.write(hist_b   + "\n")
  tmpf.write(comp_b   + "\n")
  tmpf.write(cell_b   + "\n")
  tmpf.write(lib_b    + "\n")
  tmpf.write(stage_b  + "\n")
  tmpf.write(comp_stage_b  + "\n")
  tmpf.write(user_file_b   + "\n")
  tmpf.write(org      + "\n")
  tmpf.write(method   + "\n")
  tmpf.close()
  tmpfn_a = ''
  tmpfn_b = ''
  if (filehandle_b):
    filedata = str(filehandle_b.read())

    tmpfn_b = tempfile.mktemp()
    tmpf = open(tmpfn_b, "w")
    tmpf.write(filedata)
    tmpf.close()

    if (filehandle_a):
      filedata = str(filehandle_a.read())

      tmpfn_a = tempfile.mktemp()
      tmpf = open(tmpfn_a, "w")
      tmpf.write(filedata)
      tmpf.close()

  response = BackEnd('',0,sagecgi,base,'SDGEDLibrarySelect.pl','',"'TMP_FILE','USER_FILE_A','USER_FILE_B'",request,{'TMP_FILE':tmpfn,'USER_FILE_A':tmpfn_a,'USER_FILE_B':tmpfn_b})

  if (response == ""):
    return "<br><br>There are no libraries matching the query<br><br>"

  (response_list, sdged_cache_id) = re.split("\003", response)

  ## if (filehandle_b):
  ##   local_cache_id = MakeRequest(host, port, 'MoveUploadFileToLocal(' + \
  ##     "'" + str(sdged_cache)        + "'  "   + \
  ##     ')')
  ##   sdged_cache = local_cache_id

  hidden = ""
  if (user_file_b):
    ## hidden = "<input type=hidden name='SDGED_CACHE' value=" + sdged_cache + ">"
    (sdged_cache, host_name) = re.split("HOSTNAME", sdged_cache_id)
    hidden = '<input type=hidden name="SDGED_CACHE" value=' + sdged_cache + '>'

  lines = []
  if (hidden):
    lines.append(hidden)
  lines.append(GetHiddensForSDGED(request))

  lib_header = "Library Name"
  if (user_file_b):
    if (user_file_a):
      lib_header = "File Name"
    else:
      lib_header = "Library/File Name"

  table_header = \
    "<table border=1 cellspacing=1 cellpadding=4>" + \
    "<tr bgcolor=\"#38639d\" valign=top>" + \
    "<td colspan=2><font color=\"white\"><b>Pool</b></font></td>" + \
    "<td rowspan=2><font color=\"white\"><b>Library Name</b></font></td>" + \
    "<td rowspan=2><font color=\"white\"><b>Tags</b></font></td>" + \
    "<td rowspan=2><font color=\"white\"><b>Keywords</b></font></td>" + \
    "</tr>" + \
    "<tr bgcolor=\"#38639d\" valign=top>" + \
    "<td><font color=\"white\"><b>A</b></font></td>" + \
    "<td><font color=\"white\"><b>B</b></font></td>" + \
    "</tr>\n"

  lines.append("<br><br>");

  lines.append(table_header)

  lib_list = re.split("\001", response_list)
  row_num = 0
  for i in lib_list:
    if (row_num % 300 == 0 and row_num > 0):
      lines.append("</table>")
      lines.append(table_header)
    row_num = row_num + 1
    (lid, setA, setB, lib_name, num_seqs, keywords) = re.split("\002", i)
    if save == 'yes':
      a_flag = 0
      for a_id in a_set:
        temp_a = "A_" + lid
        if( temp_a == a_id ):
          a_flag = 1
      if a_flag == 1:
        setA = " checked"
      else:
        setA = ""
      b_flag = 0
      for b_id in b_set:
        temp_b = "B_" + lid
        if( temp_b == b_id ):
          b_flag = 1
      if b_flag == 1:
        setB = " checked"
      else:
        setB = ""
    else:
      if setA == "A":
        setA = ""
        if (user_file_a):
          setA = " checked"
          setA = setA + " disabled"
          setB = setB + " disabled"
        if (user_file_b):
          setB = setB + " disabled"
      if setB == "B":
        setB = ""
        if (user_file_b):
          setB = " checked"
          setA = setA + " disabled"
          setB = setB + " disabled"
    if keywords == "":
      keywords = "&nbsp;"
    lines.append( \
      "<tr>" + \
      "<td><label for=\"A_" + lid + '"' + "></label><input type=checkbox name=A_" + lid + setA + " id=\"A_" + lid + '"' + "></td>" + \
      "<td><label for=\"B_" + lid + '"' + "></label><input type=checkbox name=B_" + lid + setB + " id=\"B_" + lid + '"' + "></td>" + \
      "<td><a href=\"SAGELibInfo?ORG=" + org + \
      "&LID=" + lid + "\">" + lib_name + "</a></td>" + \
      "<td>" + num_seqs + "</td>" + \
      "<td>" + keywords + "</td>" + \
      "</tr>" )
  lines.append("</table>")
  return string.join(lines, "\n")

######################################################################
def GetHiddensForSDGED (request):
  import string
  import re
 
  lines = []

  lines.append("<input type=hidden name=\"SAVE\">")
  lines.append("<input type=hidden name=\"CACHE\" value=0>")
##  lines.append("<input type=hidden name=\"ORG\" value=Hs>")
  lines.append("<input type=hidden name=\"PAGE\" value=1>")
  lines.append("<input type=hidden name=\"WHAT\" value=\"genes\">")
  lines.append("<input type=hidden name=\"USER_DATA_A\" value=''>")
  lines.append("<input type=hidden name=\"USER_DATA_B\" value=''>")
  lines.append(GetHiddensForSDGEDParam(request, 'SEQS'))
  lines.append(GetHiddensForSDGEDParam(request, 'SORT'))
  lines.append(GetHiddensForSDGEDParam(request, 'TITLE_A'))
  lines.append(GetHiddensForSDGEDParam(request, 'TISSUE_A'))
  lines.append(GetHiddensForSDGEDParam(request, 'HIST_A'))
  lines.append(GetHiddensForSDGEDParam(request, 'COMP_A'))
  lines.append(GetHiddensForSDGEDParam(request, 'CELL_A'))
  lines.append(GetHiddensForSDGEDParam(request, 'USER_FILE_A'))
  lines.append(GetHiddensForSDGEDParam(request, 'TITLE_B'))
  lines.append(GetHiddensForSDGEDParam(request, 'TISSUE_B'))
  lines.append(GetHiddensForSDGEDParam(request, 'HIST_B'))
  lines.append(GetHiddensForSDGEDParam(request, 'COMP_B'))
  lines.append(GetHiddensForSDGEDParam(request, 'CELL_B'))
  lines.append(GetHiddensForSDGEDParam(request, 'USER_FILE_B'))
  lines.append(GetHiddensForSDGEDParam(request, 'ORG'))
  lines.append(GetHiddensForSDGEDParam(request, 'METHOD'))
  lines.append(GetHiddensForSDGEDParam(request, 'STAGE_A'))
  lines.append(GetHiddensForSDGEDParam(request, 'STAGE_B'))

  lines.append("<input type=hidden name=\"ASEQS\" value=0>")
  lines.append("<input type=hidden name=\"BSEQS\" value=0>")
  lines.append("<input type=hidden name=\"ALIBS\" value=0>")
  lines.append("<input type=hidden name=\"BLIBS\" value=0>")
  
  return string.join(lines, "\n")

######################################################################
def GetHiddensForSDGEDParam (request, s):
  import re
  import string
  lines = []
  if request.has_key(s):
    p = request[s]
    if type(p) == type(''):
      lines.append("<input type=hidden name=\"" + s + "\" value=\"" + p + "\">")
    else:
      for i in p:
        lines.append("<input type=hidden name=\"" + s + "\" value=\"" + i + "\">")
  else:  
    lines.append("<input type=hidden name=\"" + s + "\" value=''>")
  return string.join(lines, "\n") 

 
######################################################################
## def ComputeSDGED (host, port, binpath, base, request):
## def ComputeSDGED (binpath, base, request):
def ComputeSDGED (cgapcgi, base, request):

  import string
  import re
  import tempfile
  import os
 
  page         = GetRequestParam(request, 'PAGE')
  factor       = GetRequestParam(request, 'FACTOR')
  cache        = GetRequestParam(request, 'CACHE')
  org          = GetRequestParam(request, 'ORG')
  pvalue       = GetRequestParam(request, 'PVALUE')
  chr          = GetRequestParam(request, 'CHR')
  user_email   = GetRequestParam(request, 'USER_EMAIL')
  a_seqs       = GetRequestParam(request, 'ASEQS')
  b_seqs       = GetRequestParam(request, 'BSEQS')
  a_libs       = GetRequestParam(request, 'ALIBS')
  b_libs       = GetRequestParam(request, 'BLIBS')
  method       = GetRequestParam(request, 'METHOD')
  sdged_cache  = GetRequestParam(request, 'SDGED_CACHE')
  email        = GetRequestParam(request, 'EMAIL')
  user_data_a  = GetRequestParam(request, 'USER_FILE_A')
  user_data_b  = GetRequestParam(request, 'USER_FILE_B')
 
  if( chr == "" ):
    chr = "All"
 
  GXS_ROWS_PER_PAGE = 300
  GXS_ROWS_PER_SUBTABLE = 100
 
  page = int(page)
 
  a_set = []
  b_set = []
  for k in request.form.keys():
    if (k[0:2] == 'A_'):
      a_set.append(k[2:])
    elif (k[0:2] == 'B_'):
      b_set.append(k[2:])
 
  if (user_data_b):
    if( user_data_a == user_data_b ):
      return "<br><center><b>Error: The file " + user_data_a + " in Pool A is same as the file " + user_data_b + " in Pool B."
  if len(a_set) == 0:
    if (sdged_cache == ""):
      if (cache == ""):
        return "<br><center><b>Error: each pool must contain at least one library. Pool A is empty</b></center>."
  if len(b_set) == 0:
    if (sdged_cache == ""):
      if (cache == ""):
        return "<br><center><b>Error: each pool must contain at least one library. Pool B is empty</b></center>."
  if (sdged_cache):
    if len(a_set) == 0:
      if(user_data_a == ""):
        if(cache == ""):
          return "<br><center><b>Error: each pool must contain at least one library. Pool A is empty</b></center>."
 
  if (cache == "0"):
    email = BackEnd('',0,cgapcgi,base,'CheckInput_GetCacheId.pl','',"'CHR','A_SET','B_SET'",request,{'CHR':str(chr),'A_SET':str(a_set),'B_SET':str(b_set)})
    ## cmd = binpath + "/" + "CheckInput_GetCacheId.pl " + \
    ##   "'" + str(chr)        +  "' " + \
    ##   "'" + str(a_set)      +  "' " + \
    ##   "'" + str(b_set)      +  "'"
    ## (status,email) = commands.getstatusoutput(cmd)
    ## if (re.search("Error", ) != None):
    ##   return email
    if (re.search("Error", email) != None):
      return email
 
    tmpfn = tempfile.mktemp()
    tmpf = open(tmpfn, "w")
    tmpf.write(base                    + "\n")
    tmpf.write(cache                   + "\n")
    tmpf.write(org                     + "\n")
    tmpf.write(str(page)               + "\n")
    tmpf.write(factor                  + "\n")
    tmpf.write(pvalue                  + "\n")
    tmpf.write(chr                     + "\n")
    tmpf.write(user_email              + "\n")
    tmpf.write(a_seqs                  + "\n")
    tmpf.write(b_seqs                  + "\n")
    tmpf.write(a_libs                  + "\n")
    tmpf.write(b_libs                  + "\n")
    tmpf.write(string.join(a_set, ",") + "\n")
    tmpf.write(string.join(b_set, ",") + "\n")
    tmpf.write(method                  + "\n")
    tmpf.write(sdged_cache             + "\n")
    tmpf.write(email                   + "\n")
    tmpf.close()
 
    os.chmod(tmpfn, 0777) 

    response = BackEnd('',0,cgapcgi,base,'PrepareSDGED.pl','',"'FILE'",request,{'FILE':tmpfn})
 
    if (response == ""):
      return "<br><br>There is error, please contact help desk.<br><br>"

    return response
   
  tmpfn = tempfile.mktemp()
  tmpf = open(tmpfn, "w")
  tmpf.write(base                    + "\n")
  tmpf.write(cache                   + "\n")
  tmpf.write(org                     + "\n")
  tmpf.write(str(page)               + "\n")
  tmpf.write(factor                  + "\n")
  tmpf.write(pvalue                  + "\n")
  tmpf.write(chr                     + "\n")
  tmpf.write(user_email              + "\n")
  tmpf.write(a_seqs                  + "\n")
  tmpf.write(b_seqs                  + "\n")
  tmpf.write(a_libs                  + "\n")
  tmpf.write(b_libs                  + "\n")
  tmpf.write(string.join(a_set, ",") + "\n")
  tmpf.write(string.join(b_set, ",") + "\n")
  tmpf.write(method                  + "\n")
  tmpf.write(sdged_cache             + "\n")
  tmpf.write(email                   + "\n")
  tmpf.close()
 
  response = BackEnd('',0,cgapcgi,base,'GetSDGEDInfo.pl','',"'FILE'",request,{'FILE':tmpfn})

  html_table_header = \
    "<table border=1 cellspacing=1 cellpadding=4>\n" + \
    "<tr bgcolor=\"#38639d\" valign=top>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Tag</b></font></td>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Gene or<br>Accession</b></font></td>\n" + \
    "<td colspan=2 witdh=16%><font color=\"white\"><b>Libraries</b></font></td>\n" + \
    "<td colspan=2 width=16%><font color=\"white\"><b>Tags</b></font></td>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Tag Odds A:B</b></font></td>\n" + \
    "<td nowrap rowspan=2><font color=\"white\"><b>Q</b></font></td>\n" + \
    "</tr>\n" + \
    "<tr bgcolor=\"#38639d\" valign=top>\n" + \
    "<td width=8%><font color=\"white\"><b>A</b></font></td>\n" + \
    "<td width=8%><font color=\"white\"><b>B</b></font></td>\n" + \
    "<td width=8%><font color=\"white\"><b>A</b></font></td>\n" + \
    "<td width=8%><font color=\"white\"><b>B</b></font></td>\n" + \
    "</tr>"
 
  try:
    (cache, ngenes, a_seqs, b_seqs, a_libs, b_libs, table, whole_table) = \
        re.split("\|", response)
  except:
    return "Query failed: " + response
 
  param_table = \
      "<blockquote><table border=0 cellspacing=1 cellpadding=4>\n" + \
      "<tr>\n" + \
        "<td><b>Total tags in Pool A:</b></td>" + \
        "<td>" + a_seqs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td ><b>Total tags in Pool B:</b></td>" + \
        "<td>" + b_seqs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>Total libraries in Pool A:</b></td>" + \
        "<td>" + a_libs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td ><b>Total libraries in Pool B:</b></td>" + \
        "<td>" + b_libs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>F (expression factor):</b></td>" + \
        "<td>" + factor + "X</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>Q (False discovery rate):</b></td>" + \
        "<td>" + pvalue + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>Chromosome:</b></td>" + \
        "<td>" + chr + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b><label for=\"Chromosome\">Enter Chromosome:</label></b></td>" + \
        "<td>" + "<input type=text name=\"CHR\" id=\"Chromosome\" value=\"" + chr  + "\" size=3 >" + "</td>\n" + \
        "<td>" + "<a href=\"javascript:" + \
          "document.gxs.PAGE.value=1;" + \
          "document.gxs.WHAT.value=&quot;genes&quot;;" + \
          "document.gxs.submit()\">" + \
          "<b>[Submit]</b></a> &nbsp;&nbsp;&nbsp;" + "</td>\n" + \
      "</tr>\n" + \
      "</table></blockquote\n"
 
  ngenes = int(ngenes)
  if ngenes == 0:
    if page != 0:
      lines = []
      lines.append("<form name=\"gxs\" action=\"SDGEDResults\" method=POST>")
      lines.append("<input type=hidden name=\"PAGE\">")
      lines.append("<input type=hidden name=\"WHAT\">")
      lines.append("<input type=hidden name=\"PVALUE\" value=" + pvalue + ">")
      lines.append("<input type=hidden name=\"CID\">")
      lines.append("<input type=hidden name=\"ORG\" value=" + org + ">")
      lines.append("<input type=hidden name=\"FACTOR\" value=" + factor  + ">")
      lines.append("<input type=hidden name=\"CACHE\" value=" + cache + ">")
      lines.append("<input type=hidden name=\"ASEQS\" value=" + a_seqs + ">")
      lines.append("<input type=hidden name=\"BSEQS\" value=" + b_seqs + ">")
      lines.append("<input type=hidden name=\"ALIBS\" value=" + a_libs + ">")
      lines.append("<input type=hidden name=\"BLIBS\" value=" + b_libs + ">")
      lines.append("<input type=hidden name=\"METHOD\" value=" + method + ">")
      lines.append("<input type=hidden name=\"SDGED_CACHE\" value=" + sdged_cache + ">")
      for k in request.form.keys():
        if (k[0:2] == 'A_' or k[0:2] == 'B_'):
          lines.append("<input type=hidden name=\"" + k + "\" checked>")
    return string.join(lines, "\n") + param_table + \
        "<p>No tags were found<br></form>"
  if page == 0:
    ## put org prefix so result set can be submitted to clone list generator
    table1 = []
    for i in re.split("\n", table):
      (tag, clu, sym, la, lb, sa, sb, odds, p) = re.split("\t", i)
      ## if clu is null then sym is accession, else sym is gene symbol
      if (clu != ""):
        clu = "Hs." + clu
      table1.append(string.join( \
          (tag, clu, sym, la, lb, sa, sb, odds, p), "\t") + "\n")
    return \
        "Total tags in Pool A: " + a_seqs + "\n" + \
        "Total tags in Pool B: " + b_seqs + "\n" + \
        "Total libraries in Pool A: " + a_libs + "\n" + \
        "Total libraries in Pool B: " + b_libs + "\n" + \
        "F (expression factor): " + factor + "X\n" + \
        "Q (False discovery rate): " + pvalue + "\n" + \
        "Chromosome: " + chr + "\n" + \
        "Tag\tUniGene\tGene Sym\tLibs: A\tLibs: B\t" + \
        "Seqs: A\tSeqs: B\tSeq Odds A:B\tQ\n" + string.join(table1, "")
  else:
    lines = []
    url = base + "/Genes/RunUniGeneQuery"
    lines.append("<form name=\"geneList\" action=" + url + " method=POST>")
    lines.append("<input type=hidden name=\"PAGE\" value=" + str(page) + ">")
    lines.append("<input type=hidden name=\"ORG\" value=" + org + ">")
    for i in re.split("\n", whole_table):
      (sym, clu, accs, la, lb, sa, sb, odds, p) = re.split("\t", i)
      if (clu != ''):
        if( odds == 'NaN' ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_A" + ">")
        elif( float(odds) > 1 ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_A" + ">")
        elif( float(odds) < 1 ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_B" + ">")
        elif( float(odds) == 1 ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_E" + ">")
    lines.append("<br>")
    lines.append("Get Gene List: &nbsp;&nbsp; ")
    lines.append("<a href=\"javascript:" + \
         "document.geneList.PAGE.value=" + str(page+200000) + ";" + \
         "document.geneList.submit()\">" + \
         "<b>[ A > B ]</b></a>&nbsp;&nbsp; ")
    lines.append("<a href=\"javascript:" + \
         "document.geneList.PAGE.value=" + str(page+300000) + ";" + \
         "document.geneList.submit()\">" + \
         "<b>[ A < B ]</b></a>&nbsp;&nbsp; ")
    lines.append("<a href=\"javascript:" + \
         "document.geneList.PAGE.value=" + str(page+400000) + ";" + \
         "document.geneList.submit()\">" + \
         "<b>[ All ]</b></a><br><br>")
    lines.append("</form>")

    lo = 1 + (page - 1) * GXS_ROWS_PER_PAGE
    hi = lo + GXS_ROWS_PER_PAGE - 1 
    if hi > ngenes:
      hi = ngenes
    npages = ngenes / GXS_ROWS_PER_PAGE
    if ngenes % GXS_ROWS_PER_PAGE > 0:
      npages = int(npages) + 1
    lines.append("<form name=\"gxs\" action=\"SDGEDResults\" method=POST>")
    lines.append("<input type=hidden name=\"PAGE\">")
    lines.append("<input type=hidden name=\"WHAT\">")
    lines.append("<input type=hidden name=\"PVALUE\" value=" + pvalue + ">")
    lines.append("<input type=hidden name=\"CID\">")
    lines.append("<input type=hidden name=\"ORG\" value=" + org + ">")
    lines.append("<input type=hidden name=\"FACTOR\" value=" + factor  + ">")
    lines.append("<input type=hidden name=\"CACHE\" value=" + cache + ">")
    lines.append("<input type=hidden name=\"ASEQS\" value=" + a_seqs + ">")
    lines.append("<input type=hidden name=\"BSEQS\" value=" + b_seqs + ">")
    lines.append("<input type=hidden name=\"ALIBS\" value=" + a_libs + ">")
    lines.append("<input type=hidden name=\"BLIBS\" value=" + b_libs + ">")
    lines.append("<input type=hidden name=\"METHOD\" value=" + method + ">")
    lines.append("<input type=hidden name=\"SDGED_CACHE\" value=" + sdged_cache + ">")
    for k in request.form.keys():
      if (k[0:2] == 'A_' or k[0:2] == 'B_'):
        lines.append("<input type=hidden name=\"" + k + "\" checked>")
    lines.append("Displaying " + str(lo) + " thru " + str(hi) + " of " + \
      str(ngenes) + " tags &nbsp;&nbsp;&nbsp;");
    if page < npages:
      lines.append("<a href=\"javascript:" + \
          "document.gxs.PAGE.value=" + str(page+1) + ";" + \
          "document.gxs.WHAT.value=&quot;genes&quot;;" + \
          "document.gxs.submit()\">" + \
          "Next Page</a> &nbsp;&nbsp;&nbsp;") 
    if page > 1:
      lines.append("<a href=\"javascript:" + \
          "document.gxs.PAGE.value=" + str(page-1) + ";" + \
          "document.gxs.WHAT.value=&quot;genes&quot;;" + \
          "document.gxs.submit()\">" + \
          "Prev Page</a> &nbsp;&nbsp;&nbsp;") 
    lines.append("<a href=\"javascript:" + \
        "document.gxs.PAGE.value=0;" + \
        "document.gxs.WHAT.value=&quot;genes&quot;;" + \
        "document.gxs.submit()\">" + \
        "<b>[Full Text]</b></a>") 
    lines.append(param_table)
    lines.append("<p>");
    lines.append(html_table_header)
    j = 0
    for i in re.split("\n", table):
      j = j + 1
      if j > 1 and j % GXS_ROWS_PER_SUBTABLE == 1:
        lines.append("</table>")
        lines.append(html_table_header)
      (tag, clu, sym, la, lb, sa, sb, odds, p) = re.split("\t", i);
      lines.append("<tr>")
      lines.append("<td><a href=\"" + base + "/SAGE/GeneByTag?" + \
          "ORG=" + org + "&METHOD=" + method + "&FORMAT=html&MAGIC_RANK=0&TAG=" + tag + "\">" + tag + "</a></td>")
      if (clu != ""):
        lines.append("<td><a href=\"" + base + "/Genes/GeneInfo?" + \
            "ORG=" + org + "&CID=" + clu + "\">" + sym + "</a></td>")
      else:
        if (sym == ""):
          sym = "&nbsp;"
        elif (sym == MITO_ACC):
          sym = "<font color=red>mitochondria</font>"
        lines.append("<td>" + sym + "</td>")
      if (int(la) > 0):
        lines.append("<td>" + la + "</td>")
      else:
        lines.append("<td>" + la + "</td>")
      if (int(lb) > 0):
        lines.append("<td>" + lb + "</td>")
      else:
        lines.append("<td>" + lb + "</td>")
      lines.append("<td>" + sa + "</td>")
      lines.append("<td>" + sb + "</td>")
      lines.append("<td>" + odds + "</td>")
      lines.append("<td nowrap>" + p + "</td>")
      lines.append("</tr>")
    lines.append("</table>")
    lines.append("</form>")

  return string.join(lines, "\n")

######################################################################
#def ComputeSDGED_old (binpath, base, request):
def ComputeSDGED_old (host, port, binpath, base, request):

  import string
  import re
  import tempfile

  cmd = binpath + "/" + "Check_Status.pl " 
  (status,email) = commands.getstatusoutput(cmd)
  if (re.search("Error", email) != None):
    return email
  page      = GetRequestParam(request, 'PAGE')
  factor    = GetRequestParam(request, 'FACTOR')
  cache     = GetRequestParam(request, 'CACHE')
  org       = GetRequestParam(request, 'ORG')
  pvalue    = GetRequestParam(request, 'PVALUE')
  chr       = GetRequestParam(request, 'CHR')
  a_seqs    = GetRequestParam(request, 'ASEQS')
  b_seqs    = GetRequestParam(request, 'BSEQS')
  a_libs    = GetRequestParam(request, 'ALIBS')
  b_libs    = GetRequestParam(request, 'BLIBS')
  method    = GetRequestParam(request, 'METHOD')
  sdged_cache = GetRequestParam(request, 'SDGED_CACHE')
  email = GetRequestParam(request, 'EMAIL')
  user_data_a = GetRequestParam(request, 'USER_FILE_A')
  user_data_b = GetRequestParam(request, 'USER_FILE_B')

  if( chr == "" ):
    chr = "All"

  GXS_ROWS_PER_PAGE = 300
  GXS_ROWS_PER_SUBTABLE = 100

  page = int(page)

  a_set = []
  b_set = []
  for k in request.form.keys():
    if (k[0:2] == 'A_'):
      a_set.append(k[2:])
    elif (k[0:2] == 'B_'):
      b_set.append(k[2:])

  if (user_data_b):
    if( user_data_a == user_data_b ):
      return "<br><center><b>Error: The file " + user_data_a + " in Pool A is same as the file " + user_data_b + " in Pool B."
  if len(a_set) == 0:
    if (sdged_cache == ""):
      if (cache == ""):
        return "<br><center><b>Error: each pool must contain at least one library. Pool A is empty</b></center>."
  if len(b_set) == 0:
    if (sdged_cache == ""):
      if (cache == ""):
        return "<br><center><b>Error: each pool must contain at least one library. Pool B is empty</b></center>."
  if (sdged_cache):
    if len(a_set) == 0:
      if(user_data_a == ""):
        if(cache == ""):
          return "<br><center><b>Error: each pool must contain at least one library. Pool A is empty</b></center>."

  try:
    response = MakeRequest(host, port, 'ComputeSDGED(' + \
      "'" + str(cache)              + "', "   + \
      "'" + str(org)                + "', "   + \
      "'" + str(page)               + "', "   + \
      "'" + str(factor)             + "', "   + \
      "'" + str(pvalue)             + "', "   + \
      "'" + str(chr)                + "', "   + \
      "'" + str(a_seqs)             + "', "   + \
      "'" + str(b_seqs)             + "', "   + \
      "'" + str(a_libs)             + "', "   + \
      "'" + str(b_libs)             + "', "   + \
      "'" + string.join(a_set, ",") + "', "   + \
      "'" + string.join(b_set, ",") + "', "   + \
      "'" + str(method)             + "', "   + \
      "'" + str(sdged_cache)        + "', "   + \
      "'" + str(email)              + "'  "   + \
      ')')
  except:
    return "Internal Error, please contact help desk"

  html_table_header = \
    "<table border=1 cellspacing=1 cellpadding=4>\n" + \
    "<tr bgcolor=\"#38639d\" valign=top>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Tag</b></font></td>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Gene or<br>Accession</b></font></td>\n" + \
    "<td colspan=2 witdh=16%><font color=\"white\"><b>Libraries</b></font></td>\n" + \
    "<td colspan=2 width=16%><font color=\"white\"><b>Tags</b></font></td>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Tag Odds A:B</b></font></td>\n" + \
    "<td nowrap rowspan=2><font color=\"white\"><b>Q</b></font></td>\n" + \
    "</tr>\n" + \
    "<tr bgcolor=\"#38639d\" valign=top>\n" + \
    "<td width=8%><font color=\"white\"><b>A</b></font></td>\n" + \
    "<td width=8%><font color=\"white\"><b>B</b></font></td>\n" + \
    "<td width=8%><font color=\"white\"><b>A</b></font></td>\n" + \
    "<td width=8%><font color=\"white\"><b>B</b></font></td>\n" + \
    "</tr>"

  try:
    (cache, ngenes, a_seqs, b_seqs, a_libs, b_libs, table, whole_table) = \
        re.split("\|", response)
  except:
    return "Query failed: " + response

  param_table = \
      "<blockquote><table border=0 cellspacing=1 cellpadding=4>\n" + \
      "<tr>\n" + \
        "<td><b>Total tags in Pool A:</b></td>" + \
        "<td>" + a_seqs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td ><b>Total tags in Pool B:</b></td>" + \
        "<td>" + b_seqs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>Total libraries in Pool A:</b></td>" + \
        "<td>" + a_libs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td ><b>Total libraries in Pool B:</b></td>" + \
        "<td>" + b_libs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>F (expression factor):</b></td>" + \
        "<td>" + factor + "X</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>P (significance filter):</b></td>" + \
        "<td>" + pvalue + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>Chromosome:</b></td>" + \
        "<td>" + chr + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b><label for=\"Chromosome\">Enter Chromosome:</label></b></td>" + \
        "<td>" + "<input type=text name=\"CHR\" id=\"Chromosome\" value=\"" + chr  + "\" size=3 >" + "</td>\n" + \
        "<td>" + "<a href=\"javascript:" + \
          "document.gxs.PAGE.value=1;" + \
          "document.gxs.WHAT.value=&quot;genes&quot;;" + \
          "document.gxs.submit()\">" + \
          "<b>[Submit]</b></a> &nbsp;&nbsp;&nbsp;" + "</td>\n" + \
      "</tr>\n" + \
      "</table></blockquote\n"

  ngenes = int(ngenes)
  if ngenes == 0:
    if page != 0:
      lines = []
      lines.append("<form name=\"gxs\" action=\"SDGEDResults\" method=POST>")
      lines.append("<input type=hidden name=\"PAGE\">")
      lines.append("<input type=hidden name=\"WHAT\">")
      lines.append("<input type=hidden name=\"PVALUE\" value=" + pvalue + ">")
      lines.append("<input type=hidden name=\"CID\">")
      lines.append("<input type=hidden name=\"ORG\" value=" + org + ">")
      lines.append("<input type=hidden name=\"FACTOR\" value=" + factor  + ">")
      lines.append("<input type=hidden name=\"CACHE\" value=" + cache + ">")
      lines.append("<input type=hidden name=\"ASEQS\" value=" + a_seqs + ">")
      lines.append("<input type=hidden name=\"BSEQS\" value=" + b_seqs + ">")
      lines.append("<input type=hidden name=\"ALIBS\" value=" + a_libs + ">")
      lines.append("<input type=hidden name=\"BLIBS\" value=" + b_libs + ">")
      lines.append("<input type=hidden name=\"METHOD\" value=" + method + ">")
      lines.append("<input type=hidden name=\"SDGED_CACHE\" value=" + sdged_cache + ">")
      for k in request.form.keys():
        if (k[0:2] == 'A_' or k[0:2] == 'B_'):
          lines.append("<input type=hidden name=\"" + k + "\" checked>")
    return string.join(lines, "\n") + param_table + \
        "<p>No tags were found<br></form>"
  if page == 0:
    ## put org prefix so result set can be submitted to clone list generator
    table1 = []
    for i in re.split("\n", table):
      (tag, clu, sym, la, lb, sa, sb, odds, p) = re.split("\t", i)
      ## if clu is null then sym is accession, else sym is gene symbol
      if (clu != ""):
        clu = "Hs." + clu
      table1.append(string.join( \
          (tag, clu, sym, la, lb, sa, sb, odds, p), "\t") + "\n")
    return \
        "Total tags in Pool A: " + a_seqs + "\n" + \
        "Total tags in Pool B: " + b_seqs + "\n" + \
        "Total libraries in Pool A: " + a_libs + "\n" + \
        "Total libraries in Pool B: " + b_libs + "\n" + \
        "F (expression factor): " + factor + "X\n" + \
        "P (significance filter): " + pvalue + "\n" + \
        "Chromosome: " + chr + "\n" + \
        "Tag\tUniGene\tGene Sym\tLibs: A\tLibs: B\t" + \
        "Seqs: A\tSeqs: B\tSeq Odds A:B\tQ\n" + string.join(table1, "")
  else:
    lines = []
    url = base + "/Genes/RunUniGeneQuery"
    lines.append("<form name=\"geneList\" action=" + url + " method=POST>")
    lines.append("<input type=hidden name=\"PAGE\" value=" + str(page) + ">")
    lines.append("<input type=hidden name=\"ORG\" value=" + org + ">")
    for i in re.split("\n", whole_table):
      (sym, clu, accs, la, lb, sa, sb, odds, p) = re.split("\t", i)
      if (clu != ''):
        if( odds == 'NaN' ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_A" + ">")
        elif( float(odds) > 1 ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_A" + ">")
        elif( float(odds) < 1 ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_B" + ">")
        elif( float(odds) == 1 ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_E" + ">")
    lines.append("<br>")
    lines.append("Get Gene List: &nbsp;&nbsp; ")
    lines.append("<a href=\"javascript:" + \
         "document.geneList.PAGE.value=" + str(page+200000) + ";" + \
         "document.geneList.submit()\">" + \
         "<b>[ A > B ]</b></a>&nbsp;&nbsp; ")
    lines.append("<a href=\"javascript:" + \
         "document.geneList.PAGE.value=" + str(page+300000) + ";" + \
         "document.geneList.submit()\">" + \
         "<b>[ A < B ]</b></a>&nbsp;&nbsp; ")
    lines.append("<a href=\"javascript:" + \
         "document.geneList.PAGE.value=" + str(page+400000) + ";" + \
         "document.geneList.submit()\">" + \
         "<b>[ All ]</b></a><br><br>")
    lines.append("</form>")

    lo = 1 + (page - 1) * GXS_ROWS_PER_PAGE
    hi = lo + GXS_ROWS_PER_PAGE - 1 
    if hi > ngenes:
      hi = ngenes
    npages = ngenes / GXS_ROWS_PER_PAGE
    if ngenes % GXS_ROWS_PER_PAGE > 0:
      npages = int(npages) + 1
    lines.append("<form name=\"gxs\" action=\"SDGEDResults\" method=POST>")
    lines.append("<input type=hidden name=\"PAGE\">")
    lines.append("<input type=hidden name=\"WHAT\">")
    lines.append("<input type=hidden name=\"PVALUE\" value=" + pvalue + ">")
    lines.append("<input type=hidden name=\"CID\">")
    lines.append("<input type=hidden name=\"ORG\" value=" + org + ">")
    lines.append("<input type=hidden name=\"FACTOR\" value=" + factor  + ">")
    lines.append("<input type=hidden name=\"CACHE\" value=" + cache + ">")
    lines.append("<input type=hidden name=\"ASEQS\" value=" + a_seqs + ">")
    lines.append("<input type=hidden name=\"BSEQS\" value=" + b_seqs + ">")
    lines.append("<input type=hidden name=\"ALIBS\" value=" + a_libs + ">")
    lines.append("<input type=hidden name=\"BLIBS\" value=" + b_libs + ">")
    lines.append("<input type=hidden name=\"METHOD\" value=" + method + ">")
    lines.append("<input type=hidden name=\"SDGED_CACHE\" value=" + sdged_cache + ">")
    for k in request.form.keys():
      if (k[0:2] == 'A_' or k[0:2] == 'B_'):
        lines.append("<input type=hidden name=\"" + k + "\" checked>")
    lines.append("Displaying " + str(lo) + " thru " + str(hi) + " of " + \
      str(ngenes) + " tags &nbsp;&nbsp;&nbsp;");
    if page < npages:
      lines.append("<a href=\"javascript:" + \
          "document.gxs.PAGE.value=" + str(page+1) + ";" + \
          "document.gxs.WHAT.value=&quot;genes&quot;;" + \
          "document.gxs.submit()\">" + \
          "Next Page</a> &nbsp;&nbsp;&nbsp;") 
    if page > 1:
      lines.append("<a href=\"javascript:" + \
          "document.gxs.PAGE.value=" + str(page-1) + ";" + \
          "document.gxs.WHAT.value=&quot;genes&quot;;" + \
          "document.gxs.submit()\">" + \
          "Prev Page</a> &nbsp;&nbsp;&nbsp;") 
    lines.append("<a href=\"javascript:" + \
        "document.gxs.PAGE.value=0;" + \
        "document.gxs.WHAT.value=&quot;genes&quot;;" + \
        "document.gxs.submit()\">" + \
        "<b>[Full Text]</b></a>") 
    lines.append(param_table)
    lines.append("<p>");
    lines.append(html_table_header)
    j = 0
    for i in re.split("\n", table):
      j = j + 1
      if j > 1 and j % GXS_ROWS_PER_SUBTABLE == 1:
        lines.append("</table>")
        lines.append(html_table_header)
      (tag, clu, sym, la, lb, sa, sb, odds, p) = re.split("\t", i);
      lines.append("<tr>")
      lines.append("<td><a href=\"" + base + "/SAGE/GeneByTag?" + \
          "ORG=" + org + "&METHOD=" + method + "&FORMAT=html&MAGIC_RANK=0&TAG=" + tag + "\">" + tag + "</a></td>")
      if (clu != ""):
        lines.append("<td><a href=\"" + base + "/Genes/GeneInfo?" + \
            "ORG=" + org + "&CID=" + clu + "\">" + sym + "</a></td>")
      else:
        if (sym == ""):
          sym = "&nbsp;"
        elif (sym == MITO_ACC):
          sym = "<font color=red>mitochondria</font>"
        lines.append("<td>" + sym + "</td>")
      if (int(la) > 0):
        lines.append("<td>" + la + "</td>")
      else:
        lines.append("<td>" + la + "</td>")
      if (int(lb) > 0):
        lines.append("<td>" + lb + "</td>")
      else:
        lines.append("<td>" + lb + "</td>")
      lines.append("<td>" + sa + "</td>")
      lines.append("<td>" + sb + "</td>")
      lines.append("<td>" + odds + "</td>")
      lines.append("<td nowrap>" + p + "</td>")
      lines.append("</tr>")
    lines.append("</table>")
    lines.append("</form>")

  return string.join(lines, "\n")

######################################################################
######################################################################
def Scan (input):
  import re
  for i in re.split(",", input):
    if(re.search("javascript|<script>|</script>|alert|vbscript|background\:", input, re.I) != None):
      return 'Error 1'
    if(re.search("<a.+</a>|\=|\|\||\s+\|\s+|\-\-|\+\+|\&\&|\*\*.+\*\*|<IMG\s+SRC=|';", input, re.I) != None):
      return 'Error 2'
  return ""
######################################################################
