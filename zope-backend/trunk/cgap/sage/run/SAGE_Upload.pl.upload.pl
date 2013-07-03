#!/usr/local/bin/perl
######################################################
# upload a file with netscape 2.0+ or IE 4.0+
# Muhammad A Muquit
# When: Long time ago
# Changelog:
# James Bee" &lt;JamesBee@home.com&gt; reported that from Windows filename
# such as c:\foo\fille.x saves as c:\foo\file.x, Fixed, Jul-22-1999
# Sep-30-2000, muquit@muquit.com
#   changed the separator in count.db to | from :
#   As in NT : can be a part of a file path, e.g. c:/foo/foo.txt
######################################################
#
# $Revision: 5 $
# $Author: Muquit $
# $Date: 3/28/04 9:38p $

#use strict;
use CGI;
# if you want to restrict upload a file size (in bytes), uncomment the
# next line and change the number

#$CGI::POST_MAX=50000;

$|=1;

my $version="V1.4";

## vvvvvvvvvvvvvvvvvvv MODIFY vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

# the text database  of the user. The text database contains the | 
# separated items, namely  login|encrypted password|upload path
# example: muquit|fhy687kq1hger|/usr/local/web/upload/muquit
# if no path is specified, the file must be located in the cgi-bin directory.

my $g_upload_db="upload.db";

# overwrite the existing file or not. Default is to overwrite
# chanage the value to 0 if you do not want to overwrite an existing file.
my $g_overwrite=1;

# if you want to restrict upload to files with certain extentions, change
# the value of $g_restrict_by_ext=1 and ALSO modify the @g_allowed_ext if you
# want to add other allowable extensions.
my $g_restrict_by_ext=0;
# case insensitive, so file with Jpeg JPEG GIF gif etc will be allowed
my @g_allowed_ext=("jpeg","jpg","gif","png");

## ^^^^^^^^^^^^^^^^^^^ MODIFY ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^



#-------------- globals---------- STARTS ------------------
my $query=new CGI;
my $g_debug=0;


my $g_title="File upload";
my $g_upload_path='';

#-------------- globals----------  ENDS  ------------------


print $query-&gt;header;

# Java Script for form validation
#
my $JSCRIPT=&lt;&lt;EJS;

var returnVal=true;
var DEBUG=0;

//===========================================================================
// Purpose: check if field is blank or NULL
// Params:
//  field (IN)
//  errorMsg (IN - MODIFIED)
//  fieldTitle (IN)
// Returns:
//  errorMsg - error message
// Globals:
//  sets global variable (returnVal) to FALSE if field is blank or NULL
// Comments:
//  JavaScript code adapted from netscape software registration form.
//  ma_muquit\@fccc.edu, May-09-1997
//===========================================================================

function ValidateAllFields(obj)
{
   returnVal = true;
   errorMsg = "The required field(s):\\n";

   // make sure all the fields have values
   if (isSomeFieldsEmpty(obj) == true) 
   {
     // DISPLAY ERROR MSG
     displayErrorMsg();
     returnVal = false;
   }

   if (returnVal == true)
     document.forms[0].submit();
   else
     return (false);
}

//===========================================================================
function displayErrorMsg()
{
   errorMsg += "\\nhas not been completed.";
   alert(errorMsg);
}

//===========================================================================
function isSomeFieldsEmpty(obj)
{
    var
        returnVal3=false;



// check if login is null
   if (obj.userid.value == "" || obj.userid.value == null)
   {
       errorMsg += " " + "Userid" + "\\n";
       returnVal3=true;
   }

// check if Password is null

   if (obj.password.value == "" || obj.password.value == null)
   {
       errorMsg += " " + "Password" + "\\n";
       returnVal3=true;
   }

// check if upload_file is null
   if (obj.upload_file.value == "" || obj.upload_file.value == null)
   {
       errorMsg += " " + "Upload filename" + "\\n";
       returnVal3=true;
   }

   return (returnVal3);
}

EJS
;

# print the HTML HEADER
&amp;printHTMLHeader;

if ($query-&gt;path_info eq "/author" or $query-&gt;path_info eq "/about")
{
    &amp;printForm;
    &amp;printAuthorInfo;
    return;
}

if ($query-&gt;param)
{
    &amp;doWork();
}
else
{
    &amp;printForm();
}

##-----
# printForm() - print the HTML form
##-----
sub printForm
{

    print "&lt;center&gt;\n";
    print "&lt;table border=0 bgcolor=\"#c0c0c0\" cellpadding=5 cellspacing=0&gt;\n";

    print $query-&gt;start_multipart_form,"\n";

    #------------- userid
    print "&lt;tr&gt;\n";
    print "&lt;td align=\"right\"&gt;\n";
    print "Userid:\n";
    print "&lt;/td&gt;\n";
    
    print "&lt;td&gt;\n";
    print $query-&gt;textfield(-name=&gt;'userid',
            -size=&gt;20);
    print "&lt;/td&gt;\n";
    print "&lt;/tr&gt;\n";

    #------------- password
    print "&lt;tr&gt;\n";
    print "&lt;td align=\"right\"&gt;\n";
    print "Password:\n";
    print "&lt;/td&gt;\n";
    
    print "&lt;td&gt;\n";
    print $query-&gt;password_field(-name=&gt;'password',
            -size=&gt;20);
    print "&lt;/td&gt;\n";
    print "&lt;/tr&gt;\n";

    #------------- upload
    print "&lt;tr&gt;\n";
    print "&lt;td align=\"right\"&gt;\n";
    print "Upload file:\n";
    print "&lt;/td&gt;\n";
    
    print "&lt;td&gt;\n";
    print $query-&gt;filefield(-name=&gt;'upload_file',
            -size=&gt;30,
            -maxlength=&gt;80);
    print "&lt;/td&gt;\n";
    print "&lt;/tr&gt;\n";



    #------------- submit
    print "&lt;tr&gt;\n";
    print "&lt;td colspan=2 align=\"center\"&gt;\n";
    print "&lt;hr noshade size=1&gt;\n";
    print $query-&gt;submit(-label=&gt;'Upload',
            -value=&gt;'Upload',
            -onClick=&gt;"return ValidateAllFields(this.form)"),"\n";
    print "&lt;/td&gt;\n";
    print "&lt;/tr&gt;\n";



    print $query-&gt;endform,"\n";

    print "&lt;/table&gt;\n";
    print "&lt;/center&gt;\n";
}



##------
# printHTMLHeader()
##------
sub printHTMLHeader
{
    print $query-&gt;start_html(
            -title=&gt;"$g_title",
            -script=&gt;$JSCRIPT,
            -bgcolor=&gt;"#ffffff",
            -link=&gt;"#ffff00",
            -vlink=&gt;"#00ffff",
            -alink=&gt;"#ffff00",
            -text=&gt;"#000000");
}

##-------
# doWork() - upload file 
##-------
sub doWork
{
    ##################
    my $em='';
    ##################


    # import the paramets into a series of variables in 'q' namespace
    $query-&gt;import_names('q');
    #  check if the necessary fields are empty or not
    $em .= "&lt;br&gt;You must specify your Userid!&lt;br&gt;" if !$q::userid;
    $em .= "You must specify your Password!&lt;br&gt;" if !$q::password;
    $em .= "You must select a file to upload!&lt;br&gt;" if !$q::upload_file;

    &amp;printForm();
    if ($em)
    {
        &amp;printError($em);
        return;
    }

    if (&amp;validateUser() == 0)
    {
        &amp;printError("Will not upload! Could not validate Userid: $q::userid");
        return;
    }

    # if you want to restrict upload to files with certain extention
    if ($g_restrict_by_ext == 1)
    {
        my $file=$q::upload_file;
        my @ta=split('\.',$file);
        my $sz=scalar(@ta);
        if ($sz &gt; 1)
        {
            my $ext=$ta[$sz-1];
            if (! grep(/$ext/i,@g_allowed_ext))
            {
                &amp;printError("You are not allowed to upload this file");
                return;
            }

        }
        else
        {
            &amp;printError("You are not allowed to upload this file");
             return;
        }
    }

    # now upload file
    &amp;uploadFile();

    if ($g_debug == 1)
    {
        my @all=$query-&gt;param;
        my $name;
        foreach $name (@all)
        {
            print "$name -&gt;", $query-&gt;param($name),"&lt;br&gt;\n";
        }
    }
}

##------
# printError() - print error message
##------
sub printError
{
    my $em=shift;
    print&lt;&lt;EOF;
&lt;center&gt;
    &lt;hr noshade size=1 width="80%"&gt;
        &lt;table border=0 bgcolor="#000000" cellpadding=0 cellspacing=0&gt;
        &lt;tr&gt;
            &lt;td&gt;
                &lt;table border=0 width="100%" cellpadding=5 cellspacing=1&gt;
                    &lt;tr"&gt;
                        &lt;td bgcolor="#ffefd5" width="100%"&gt;
                        
                        &lt;font color="#ff0000"&gt;&lt;b&gt;Error -&lt;/b&gt;&lt;/font&gt;
                        $em&lt;/td&gt;
                    &lt;/tr&gt;
                &lt;/table&gt;
            &lt;/td&gt;
        &lt;/tr&gt;
            
        &lt;/table&gt;
&lt;/center&gt;
EOF
;
}

##--
# validate login name
# returns 1, if validated successfully
#         0 if  validation fails due to password or non existence of login 
#           name in text database
##--
sub validateUser
{
    my $rc=0;
    my ($u,$p);
    my $userid=$query-&gt;param('userid');
    my $plain_pass=$query-&gt;param('password');

    # open the text database
    unless(open(PFD,$g_upload_db))
    {
        my $msg=&lt;&lt;EOF;
Could not open user database: $g_upload_db
&lt;br&gt;
Reason: $!
&lt;br&gt;
Make sure that your web server has read permission to read it.
EOF
;
        &amp;printError("$msg");
        return;
    }
    
    # first check if user exist
    $g_upload_path='';
    my $line='';
    while (&lt;PFD&gt;)
    {
        $line=$_;
        chomp($line);
        # get rid of CR
        $line =~~ s/\r$//g;
        ($u,$p,$g_upload_path)=split('\|',$line);
        if ($userid eq $u)
        {
            $rc=1;
            last;
        }
    }
    close(PFD);

    if (crypt($plain_pass,$p) ne $p)
    {
        $rc=0;
    }
    
    return ($rc);
}

##--------
# uploadFile()
##--------
sub uploadFile
{
    my $bytes_read=0;
    my $size='';
    my $buff='';
    my $start_time;
    my $time_took;
    my $filepath='';
    my $filename='';
    my $write_file='';

    $filepath=$query-&gt;param('upload_file');

    # James Bee" &lt;JamesBee@home.com&gt; reported that from Windows filename
    # such as c:\foo\fille.x saves as c:\foo\file.x, so we've to get the
    # filename out of it
    # look at the last word, hold 1 or more chars before the end of the line
    # that doesn't include / or \, so it will take care of unix path as well
    # if it happens, muquit, Jul-22-1999
    if ($filepath =~~ /([^\/\\]+)$/)
    {
        $filename="$1";
    }
    else
    {
        $filename="$filepath";
    }
    # if there's any space in the filename, get rid of them
    $filename =~~ s/\s+//g;

    $write_file="$g_upload_path" . "/" . "$filename";    

    &amp;print_debug("Filename=$filename");
    &amp;print_debug("Writefile= $write_file");

    if ($g_overwrite == 0)
    {
        if (-e $write_file)
        {
            &amp;printError("File $filename exists, will not overwrite!");
            return;
        }
    }

    if (!open(WFD,"&gt;$write_file"))
    {
        my $msg=&lt;&lt;EOF;
Could not create file: &lt;code&gt;$write_file&lt;/code&gt;
&lt;br&gt;
It could be:
&lt;ol&gt;
&lt;li&gt;The upload directory: &lt;code&gt;\"$g_upload_path\"&lt;/code&gt; does not have write permission for the
web server.
&lt;li&gt;The upload.db file has Control character at the end of line
&lt;/ol&gt;
EOF
;

        &amp;printError("$msg");
        return;
    }

    $start_time=time();
    while ($bytes_read=read($filepath,$buff,2096))
    {
        $size += $bytes_read;
        binmode WFD;
        print WFD $buff;
    }

    &amp;print_debug("size= $size");

    close(WFD);

    if ((stat $write_file)[7] &lt;= 0)
    {
        unlink($write_file);
        &amp;printError("Could not upload file: $filename");
        return;
    }
    else
    {
        $time_took=time()-$start_time;
    print&lt;&lt;EOF;
&lt;center&gt;
    &lt;hr noshade size=1 width="90%"&gt;
        &lt;table border=0 bgcolor="#c0c0c0" cellpadding=0 cellspacing=0&gt;
        &lt;tr&gt;
            &lt;td&gt;
                &lt;table border=0 width="100%" cellpadding=10 cellspacing=2&gt;
                    &lt;tr align="center"&gt;
                        &lt;td bgcolor="#000099" width="100%"&gt;
                        &lt;font color="#ffffff"&gt;
                        File 
                        &lt;font color="#00ffff"&gt;&lt;b&gt;$filename&lt;/b&gt;&lt;/font&gt; of size 
                        &lt;font color="#00ffff"&gt;&lt;b&gt;$size&lt;/b&gt;&lt;/font&gt; bytes is 
                        uploaded successfully!
                        &lt;/font&gt;
                        &lt;/td&gt;
                    &lt;/tr&gt;
                &lt;/table&gt;
            &lt;/td&gt;
        &lt;/tr&gt;
            
        &lt;/table&gt;
&lt;/center&gt;
EOF
;
    }
}

sub printAuthorInfo
{
    my $url="http://www.muquit.com/muquit/";
    my $upl_url="http://muquit.com/muquit/software/upload_pl/upload_pl.html";
    print&lt;&lt;EOF;
&lt;center&gt;
    &lt;hr noshade size=1 width="90%"&gt;
        &lt;table border=0 bgcolor="#c0c0c0" cellpadding=0 cellspacing=0&gt;
        &lt;tr&gt;
            &lt;td&gt;
                &lt;table border=0 width="100%" cellpadding=10 cellspacing=2&gt;
                    &lt;tr align="center"&gt;
                        &lt;td bgcolor="#000099" width="100%"&gt;
                        &lt;font color="#ffffff"&gt;
                        &lt;a href="$upl_url"&gt;
                        upload.pl&lt;/a&gt; $version by 
                        &lt;a href="$url"&gt;Muhammad A Muquit&lt;/A&gt;
                        &lt;/font&gt;
                        &lt;/td&gt;
                    &lt;/tr&gt;
                &lt;/table&gt;
            &lt;/td&gt;
        &lt;/tr&gt;
            
        &lt;/table&gt;
&lt;/center&gt;
EOF
;
}

sub print_debug
{
    my $msg=shift;
    if ($g_debug)
    {
        print "&lt;code&gt;(debug) $msg&lt;/code&gt;&lt;br&gt;\n";
    }
}
