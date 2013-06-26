#! /usr/bin/python

from socket import *
from Blocks import *

## Message status codes

S_REQUEST       = '0'   ## The transmission is a request
S_OK            = '1'   ## Request was well-formed, and server
                        ## found data matching the query  
S_NO_DATA       = '2'   ## Request was well-formed, but server
                        ## found no data matching the query
S_BAD_REQUEST   = '3'   ## The request was not well-formed
S_RESPONSE_FAIL = '4'   ## Server failed

global_response_status = S_OK

######################################################################
def GlobalResponseStatus ():
  return global_response_status

######################################################################
def MakeRequest (host, port, req):

  global global_response_status

  try:
    s = socket(AF_INET, SOCK_STREAM)
    s.connect((host, port))
    SendBlocks(s, S_REQUEST, req)
    (global_response_status, s1) = RecvBlocks(s)
    s.close()
  except:
    global_response_status = S_RESPONSE_FAIL
    s1 = "Database temporarily unavailable"
  return s1

######################################################################
def GetRequestParam (request, s):
  import re
  import string
  if request.has_key(s):
    p = request[s]
    if type(p) == type(''):
      q = p
    else:
      q = string.join(p, ",")
  else:
    q = ''
  return re.sub("'", "\\'", q, 0)

######################################################################
def BaseHref (parents):
  j = ""
  for i in parents[:-2]:
    j = str(i.id) + "/" + j
  return j

######################################################################
def BackEnd (host, port, path, base, cmd, \
    requestparamnames, otherparamnames, request, other):

  import re
  import string
  import tempfile
  import urllib
  import commands  

  p = []

  if host == "" and path != "":
    usesocket = 0
    if re.compile("^http:", re.I).match(path):
      usehttp = 1
      useexec = 0
    else:
      usehttp = 0 
      useexec = 1
##    tmpfn = tempfile.mktemp()
##    tmpf = open(tmpfn, "w")
  elif path == "" and host != "":
    usesocket = 1
    useexec   = 0
    usehttp   = 0
  else:
    return "Error: host and path are both specified"

  if usehttp:
    other['BASE'] = base
  elif usesocket:
    p.append("'" + base + "'")
  elif useexec:
    p.append("'" + base + "'")

## if type is file, the file name would use filenameFILE as prefix or just it,
## so here to check the name, if the name match it, it will read the file.
  for i in re.split(",", requestparamnames):
    if (re.match("^filenameFILE", i) != None):
      filehandle  = request.form[i]
      if (filehandle):
        param = str(filehandle.read())
        param = re.sub("^\s+", "", param)
        param = re.sub("\s+$", "", param)
      else:
        param = ''
    else:
      param = str(GetRequestParam(request, i))
      param = re.sub("^\s+", "", param)
      param = re.sub("\s+$", "", param)
    if usesocket:
      p.append("'" + param + "'")
    elif useexec or usehttp:
      if usehttp:                 ## move relevant request params to other
        if other.has_key(i):
          if type(other[i]) == type(''):
            if other[i] == "" and param != "":
              other[i] = param
            else:
              pass
          else:
            other[i].append(param)
        else:
          other[i] = param
      else:
        p.append("'" + param + "'")
##      tmpf.write(param + "\n")

  for i in re.split(",", otherparamnames):
    param = str(GetRequestParam(other, i))
    #Was request above
    param = re.sub("^\s+", "", param)
    param = re.sub("\s+$", "", param)
    if usesocket:
      p.append("'" + param + "'")
    elif useexec:
      if usehttp:
        pass
      else:
        p.append("'" + param + "'")
##      tmpf.write(param + "\n")

  if useexec:
    (status,response) = commands.getstatusoutput \
        (path + "/" + cmd + " "  + string.join(p, " "))
##    tmpf.close()

  elif usehttp:
    httpcmd = path + "/" + cmd
    f = urllib.urlopen(httpcmd, urllib.urlencode(other))
    response = f.read()

  elif usesocket:
    response = MakeRequest(host, port, cmd + "(" + string.join(p, ", ") + ")" )

  return response

######################################################################
def BackEnd2 (host, port, path, base, cmd, \
    requestparamnames, otherparamnames, request, other, file_a, file_b):

  import re
  import string
  import tempfile
  import urllib
  import commands

  p = []

  try:
    data_a = file_a.readlines()
  except:
    pass;
  for d in data_a:
    d  = re.sub("\s+", " ", d)
    d  = re.sub("^\s+", "", d)
    d  = re.sub("\s+$", "", d)

  if host == "" and path != "":
    usesocket = 0
    if re.compile("^http:", re.I).match(path):
      usehttp = 1
      useexec = 0
    else:
      usehttp = 0
      useexec = 1
##    tmpfn = tempfile.mktemp()
##    tmpf = open(tmpfn, "w")
  elif path == "" and host != "":
    usesocket = 1
    useexec   = 0
    usehttp   = 0
  else:
    return "Error: host and path are both specified"

  if usehttp:
    other['BASE'] = base
  elif usesocket:
    p.append("'" + base + "'")
  elif useexec:
    p.append("'" + base + "'")

## if type is file, the file name would use filenameFILE as prefix or just it,
## so here to check the name, if the name match it, it will read the file.
  for i in re.split(",", requestparamnames):
    if (re.match("^filenameFILE", i) != None):
      filehandle  = request.form[i]
      if (filehandle):
        param = str(filehandle.read())
        param = re.sub("^\s+", "", param)
        param = re.sub("\s+$", "", param)
      else:
        param = ''
    else:
      param = str(GetRequestParam(request, i))
      param = re.sub("^\s+", "", param)
      param = re.sub("\s+$", "", param)
    if usesocket:
      p.append("'" + param + "'")
    elif useexec or usehttp:
      if usehttp:                 ## move relevant request params to other
        if other.has_key(i):
          if type(other[i]) == type(''):
            if other[i] == "" and param != "":
              other[i] = param
            else:
              pass
          else:
            other[i].append(param)
        else:
          other[i] = param
      else:
        p.append("'" + param + "'")
##      tmpf.write(param + "\n")

  for i in re.split(",", otherparamnames):
    param = str(GetRequestParam(other, i))
    #Was request above
    param = re.sub("^\s+", "", param)
    param = re.sub("\s+$", "", param)
    if usesocket:
      p.append("'" + param + "'")
    elif useexec:
      if usehttp:
        pass
      else:
        p.append("'" + param + "'")
##      tmpf.write(param + "\n")

  if useexec:
    (status,response) = commands.getstatusoutput \
        (path + "/" + cmd + " "  + string.join(p, " "))
##    tmpf.close()

  elif usehttp:
    httpcmd = path + "/" + cmd
    f = urllib.urlopen(httpcmd, urllib.urlencode(other))
    response = f.read()

  elif usesocket:
    response = MakeRequest(host, port, cmd + "(" + string.join(p, ", ") + ")" )

  return response

######################################################################
def Scan ( requestparamnames, request):
 
  import re
  import string
  import tempfile
  import urllib
  import commands
 
  p = []
 
## so here to check the name, if the name match it, it will read the file.
  for i in re.split(",", requestparamnames):
    if (re.compile("javascript", re.I) != None):
      return 0
    if (re.compile("<script>", re.I) != None):
      return 0
    if (re.compile("</script>", re.I) != None):
      return 0
    if (re.compile("vbscript", re.I) != None):
      return 0
    if (re.compile("\<a.*\<\/a\>", re.I) != None):
      return 0
    if (re.compile(".*=.*", re.I) != None):
      return 0
    if (re.compile("\|\|", re.I) != None):
      return 0
    if (re.compile("\-\-", re.I) != None):
      return 0
    if (re.compile("\*\*", re.I) != None):
      return 0
    if (re.compile("IMG\s*SRC=", re.I) != None):
      return 0

  return 1
