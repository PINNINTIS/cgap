#! /usr/local/bin/python

from socket import *

## BLOCKSIZE = 65536
## BLOCKSIZE = 32768
## BLOCKSIZE = 16384
## BLOCKSIZE = 8192
## BLOCKSIZE = 4096
## BLOCKSIZE = 2049
BLOCKSIZE = 4096

## Message status codes

     ##
     ## Set by sender:
     ##
S_REQUEST       = '0'   ## The transmission is a request
S_OK            = '1'   ## Request was well-formed, and server
                        ## found data matching the query  
S_NO_DATA       = '2'   ## Request was well-formed, but server
                        ## found no data matching the query
S_BAD_REQUEST   = '3'   ## The request was not well-formed
S_RESPONSE_FAIL = '4'   ## Server failed
     ##
     ## Set by receiver:
     ##
S_RECEIVE_FAIL  = '5'   ## Incoming transmission not received properly

#HDR_SZ = 2        ## First byte: is this the last block
                  ## Second byte: message status code

HDR_SZ = 7
  ## First byte: is this block the last block
  ## Second byte: message status code
  ## Third thru seventh bytes: length of actual data in this block,
  ##    as a character string, with leading spaces

global_response_status = S_OK

######################################################################
def TestBlocksGet (host, port, file):
  return MakeRequest(host, port, 'Get(' + str(file) + ')')

######################################################################
def GlobalResponseStatus ():
  return global_response_status

######################################################################
def SendBlocks (handle, data):
  import string

  data_length = len(data)
  written = 0
  while (data_length > 0):
    if (data_length > (BLOCKSIZE - HDR_SZ)):
      length = BLOCKSIZE - HDR_SZ
    else:
      length = data_length
    data_length = data_length - length
    if (data_length > 0):
      flag = 1
    else:
      flag = 0
    length_spec = "%5d" % length
    buffer = str(flag) + S_REQUEST + length_spec + \
        data[written:(written+length)]
    handle.send(buffer)
    written = written + length

######################################################################
def RecvBlocks (handle):
  import string
  lines = []
  while (1):
    got = 0
    header1 = ''
    header  = ''
    while (got < HDR_SZ):
      header1 = handle.recv(HDR_SZ - got)
      print "received header:" + header1    ##
      got = got + len(header1)
      header = header + header1
    data_length = int(header[2:7])
    print "data length = " + str(data_length)
    while (data_length > 0):
      buf = handle.recv(data_length)
      data_length = data_length - len(buf)
      print "received = " + str(len(buf))             ##
      lines.append(buf)
    if header[0] == '0':
      break
  return (header[1], string.join(lines, ""))

######################################################################
def MakeRequest (host, port, req):

  global global_response_status

  try:
    s = socket(AF_INET, SOCK_STREAM)
    s.connect((host, port))
    SendBlocks(s, req)
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
    param = str(GetRequestParam(request, i))
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

