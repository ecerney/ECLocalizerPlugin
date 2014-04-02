import sys
import os, re, subprocess, sys
import fnmatch
import argparse
import shutil
import xlwt, xlrd


def get_file_folder_name(file):
    filecomponents = file.split('/')
    foldername = filecomponents[len(filecomponents)-2]
    noextention = foldername.split('.')[0]
    return noextention

def verify_text_format(content, file = None):
    badlines = []
    lines = re.split("\r?\n", content);
    emptylineregex = re.compile(r'^\s*$')
    formatregex    = re.compile(r'^("([^"\\]*(?:\\.[^"\\]*)*)") = ("([^"\\]*(?:\\.[^"\\]*)*)";)')
    fileregex   = re.compile(r'/\*(.)*\*/')
    commentregex = re.compile(r'// .*')
    
    i = 1
    for line in lines[:]:
        result1 = emptylineregex.search(line)
        result2 = formatregex.search(line)
        result3 = fileregex.search(line)
        result4 = commentregex.search(line)
        
        if (result1 is None and result2 is None and result3 is None and result4 is None):
            print line
            badlines.append(i);
        i = i + 1
    
    if (len(badlines) > 0):
        if file:
            print "Bad Lines In File: " + file
        else:
            print "Bad Lines In Generated Strings"
        
        print badlines
        return False
    return True

oldFile = str(sys.argv[1])
newFile = str(sys.argv[2])

workbook = xlrd.open_workbook(newFile)
worksheet = workbook.sheet_by_name(workbook.sheet_names()[0])

num_rows = worksheet.nrows - 1
curr_row = 0
outputstring = ''

while curr_row < num_rows:
    curr_row += 1
    row = worksheet.row(curr_row)
    
    # Cell Types: 0=Empty, 1=Text, 2=Number, 3=Date, 4=Boolean, 5=Error, 6=Blank
    if (worksheet.cell_type(curr_row, 0) == 1) and (worksheet.cell_type(curr_row, 1) == 1):
        key = worksheet.cell_value(curr_row, 0).rstrip().lstrip()
        trans = worksheet.cell_value(curr_row, 1).rstrip().lstrip()
        
        outputstring += key + ' = ' + trans + '\n\n'

if verify_text_format(outputstring):
    outfile = open(oldFile, 'w')
    outfile.write(outputstring.encode('utf8'))
    outfile.close()