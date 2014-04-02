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


print len(sys.argv)
if len(sys.argv) == 4:
    existingFile = str(sys.argv[3])
else:
    existingFile = ''

basePath = str(sys.argv[1])
inputString = str(sys.argv[2])

inputLines = re.split("\r?\n", inputString);
# prepare regexes
firstregex = re.compile(r'^("([^"\\]*(?:\\.[^"\\]*)*)")')
secondregex= re.compile(r'("([^"\\]*(?:\\.[^"\\]*)*)";)')
fileregex  =re.compile(r'/\*.*[^*/]\*/')
commentregex = re.compile(r'// .*')

book = xlwt.Workbook(encoding='utf-8')

if (existingFile != ''):
    languagename = get_file_folder_name(existingFile)
else:
    languagename = 'en'

sh = book.add_sheet(languagename.upper())
style = xlwt.XFStyle()
font = xlwt.Font()
font.bold = True
font.height = 14 * 20
style.font = font

sh.col(0).width = 256 * 70
sh.col(1).width = 256 * 70
sh.col(2).width = 256 * 12
sh.col(3).width = 256 * 120
sh.col(4).width = 256 * 70

sh.write(0, 0, 'English Text', style=style)
sh.write(0, 1, languagename.upper() + ' Translation', style=style)
sh.write(0, 2, 'New Flag', style=style)
sh.write(0, 3, 'File', style=style)
sh.write(0, 4, 'Comment', style=style)

row = 1

style2 = xlwt.XFStyle()
style2.alignment.wrap = 1
font2 = xlwt.Font()
font2.bold = False
font2.height = 12 * 20
style2.font = font2

if (existingFile != ''):
    with open(existingFile, 'r') as f:
        tempcontent = f.read()
        templines = re.split("\r?\n", tempcontent);
        
        for line in inputLines[:]:
            result1 = firstregex.search(line)
            result1end = secondregex.search(line)
            
            if (result1):
                foundmatch = 0
                for line2 in templines[:]:
                    result2 = firstregex.search(line2)
                    result2end = secondregex.search(line2)
                    if (result2 and result2.group(1) == result1.group(1)):
                        foundmatch = 1
                        sh.write(row, 0, result1.group(1), style=style2)
                        sh.write(row, 1, result2end.group(1), style=style2)
                        break
                if (foundmatch != 1):
                    sh.write(row, 0, result1.group(1), style=style2)
                    sh.write(row, 1, result1end.group(1), style=style2)
                    sh.write(row, 2, ' /* New */', style=style2)
            elif (fileregex.search(line)):
                sh.write(row, 3, line, style2)
                row-=1
            elif (commentregex.search(line)):
                sh.write(row, 4, line, style2)
                row-=1
            else:
                sh.write(row, 0, line, style2)
            
            row+=1
else:
    for line in inputLines[:]:
        result1 = firstregex.search(line)
        result1end = secondregex.search(line)
        
        if (result1):
            sh.write(row, 0, result1.group(1), style=style2)
            sh.write(row, 1, result1end.group(1), style=style2)
            sh.write(row, 2, ' /* New */', style=style2)
        elif (fileregex.search(line)):
            sh.write(row, 3, line, style2)
            row-=1
        elif (commentregex.search(line)):
            sh.write(row, 4, line, style2)
            row-=1
        else:
            sh.write(row, 0, line, style2)
        
        row+=1

book.save(basePath + '/Localization-' + languagename.upper() + '.xls')
