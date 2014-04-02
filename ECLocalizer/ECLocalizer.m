//
//  ECLocalizer.m
//  ECLocalizer
//
//  Created by Eric Cerney on 3/28/14.
//    Copyright (c) 2014 Eric Cerney. All rights reserved.
//

#import "ECLocalizer.h"
#include <Python.h>

static ECLocalizer *sharedPlugin;

@interface ECLocalizer ()

@property (nonatomic, strong) NSBundle *bundle;

@property (nonatomic, strong) NSURL *destinationURL;
@property (nonatomic, strong) NSArray *existingLocalizationFiles;

@end

@implementation ECLocalizer

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static id sharedPlugin = nil;
	static dispatch_once_t onceToken;
	NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
	if ([currentApplicationName isEqual:@"Xcode"]) {
		dispatch_once(&onceToken, ^{
		    sharedPlugin = [[self alloc] initWithBundle:plugin];
            
		    NSLog(@"ECLocalizer Successfully Loaded!");
		});
	}
}

- (id)initWithBundle:(NSBundle *)plugin
{
	if (self = [super init]) {
		// reference to plugin's bundle, for resource acccess
		self.bundle = plugin;
        
		// Create menu items, initialize UI, etc.
        
        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"File"];
		if (menuItem) {
			[[menuItem submenu] addItem:[NSMenuItem separatorItem]];
            
            NSMenu *localizeCodeMenu = [[NSMenu alloc] initWithTitle:@"Localization"];
            
			NSMenuItem *exportCurrentProject = [[NSMenuItem alloc] initWithTitle:@"Export Current Project" action:@selector(generateFilesFromCurrentPath) keyEquivalent:@"l"];
			[exportCurrentProject setKeyEquivalentModifierMask:NSControlKeyMask | NSCommandKeyMask | NSAlternateKeyMask];
            [exportCurrentProject setTarget:self];
            [localizeCodeMenu addItem:exportCurrentProject];
            
            NSMenuItem *exportSelectedFiles = [[NSMenuItem alloc] initWithTitle:@"Export Select Files" action:@selector(generateFilesFromSelectedPath) keyEquivalent:@"k"];
			[exportSelectedFiles setKeyEquivalentModifierMask:NSControlKeyMask | NSCommandKeyMask | NSAlternateKeyMask];
            [exportSelectedFiles setTarget:self];
            [localizeCodeMenu addItem:exportSelectedFiles];
            
            [localizeCodeMenu addItem:[NSMenuItem separatorItem]];
            
            NSMenuItem *importSelectedProject = [[NSMenuItem alloc] initWithTitle:@"Import Selected Files" action:@selector(importFilesFromSelectedPath) keyEquivalent:@"i"];
			[importSelectedProject setKeyEquivalentModifierMask:NSControlKeyMask | NSCommandKeyMask | NSAlternateKeyMask];
            [importSelectedProject setTarget:self];
            [localizeCodeMenu addItem:importSelectedProject];
            
            NSMenuItem *localizeCodeMenuItem = [[NSMenuItem alloc] initWithTitle:@"Localization" action:nil keyEquivalent:@""];
            [localizeCodeMenuItem setSubmenu:localizeCodeMenu];
            [[menuItem submenu] addItem:localizeCodeMenuItem];
		}
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - User interaction

- (NSArray *)getInputURLsWithTitle:(NSString *)title
{
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:YES];
	[openDlg setPrompt:@"Select"];
    [openDlg setTitle:@"Choose Input File(s)/Folder"];
	[openDlg setAllowsMultipleSelection:YES];
	[openDlg setCanChooseDirectories:YES];
    
	if ([openDlg runModal] == NSOKButton) {
		NSArray *files = [openDlg URLs];
        
        return files;
	}
    else {
        return nil;
    }
}

- (NSURL *)getDestinationPathWithTitle:(NSString *)title
{
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:NO];
    [openDlg setCanChooseDirectories:YES];
	[openDlg setPrompt:@"Select"];
    [openDlg setTitle:@"Choose Output Folder"];
	[openDlg setAllowsMultipleSelection:NO];
    [openDlg setCanCreateDirectories:YES];
    
	if ([openDlg runModal] == NSOKButton) {
		NSArray *files = [openDlg URLs];
        
        return [files firstObject];
    }
    else {
        return nil;
    }
}


#pragma mark - Import Selected Flow

- (void)importFilesFromSelectedPath
{
    // Get XLS Files
    NSArray *inputExcelFiles = [self getInputURLsWithTitle:@"Choose Excel File(s)/Folder"];
    NSMutableArray *excelFiles = [NSMutableArray array];
    for (int i = 0; i < [inputExcelFiles count]; i++) {
        NSURL *fileURL = [inputExcelFiles objectAtIndex:i];
        
        NSArray *matches = [self excelFilesFromURL:fileURL];
        
        if (matches.count) {
            [excelFiles addObjectsFromArray:matches];
        }
    }
    
    NSURL *outputStringFolder = [self getDestinationPathWithTitle:@"Choose Output Folder"];
    
    if ([[outputStringFolder pathExtension] isEqualToString:@"lproj"]) {
        NSURL *matchingExcelURL = nil;
        
        for (NSURL *xlFile in excelFiles) {
            NSString *newAbbr = [[self fileLanguageAbbreviationForString:xlFile.lastPathComponent] lowercaseString];
            
            if ([outputStringFolder.lastPathComponent isEqualToString:[NSString stringWithFormat:@"%@.lproj", newAbbr]]) {
                matchingExcelURL = xlFile;
                break;
            }
        }
        
        if (matchingExcelURL) {
            NSString *newFilePath = [outputStringFolder.path stringByAppendingPathComponent:@"Localizable.strings"];
            
            NSURL *newFileURL = [NSURL fileURLWithPath:newFilePath];
            
            [self importExcelFilesAtURL:matchingExcelURL toStringsFile:newFileURL];
            
            NSAlert *alert = [NSAlert alertWithMessageText:@"Import Complete" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Your strings file has been created at the location specified."];
            [alert runModal];
        }
        else {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Import Error" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Selected lproj folder doesn't match any of the supplied xls file(s)"];
            [alert runModal];
        }
    }
    else {
        for (NSURL *xlFile in excelFiles) {
            NSString *newAbbr = [[self fileLanguageAbbreviationForString:xlFile.lastPathComponent] lowercaseString];
            
            NSString *newFolderPath = [outputStringFolder.path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.lproj", newAbbr]];
            
            NSURL *newFolderURL = [NSURL fileURLWithPath:newFolderPath];
            
            [[NSFileManager defaultManager] createDirectoryAtURL:newFolderURL
                                     withIntermediateDirectories:YES attributes:nil error:nil];
            
            NSString *newFilePath = [newFolderPath stringByAppendingPathComponent:@"Localizable.strings"];
            
            NSURL *newFileURL = [NSURL fileURLWithPath:newFilePath];
            
            [self importExcelFilesAtURL:xlFile toStringsFile:newFileURL];
        }
        
        NSAlert *alert = [NSAlert alertWithMessageText:@"Import Complete" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Your .strings files have been created at the location specified."];
        [alert runModal];
    }
}


#pragma mark - Current Path Flow

- (void)generateFilesFromCurrentPath
{
    NSURL *currentURL = [self currentWorkspaceURL];
    
    // Get Source files
    NSArray *sourceFiles = [self sourceFilesFromURL:currentURL];
    
    // Get Existing Strings files
    NSArray *stringsFiles = [self localizationFilesFromURL:currentURL];
    
    // Get Output location
    NSURL *outputURL = [self getDestinationPathWithTitle:@"Choose Output Folder"];
    
    if (sourceFiles.count && outputURL) {
        NSArray *strings = [self localizationStringsFromFiles:sourceFiles];
        
        NSArray *uniqueStrings = [self uniqueStringsFromArray:strings];
        
        NSString *formattedString = [self formattedStringFromStrings:uniqueStrings];
        
        [self createExcelFilesFromString:formattedString existingFiles:stringsFiles destinationURL:outputURL];
        
        NSAlert *alert = [NSAlert alertWithMessageText:@"Export Complete" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Your excel files have been created at the location specified."];
        [alert runModal];
    }
}


#pragma mark - Selected Path Flow

- (void)generateFilesFromSelectedPath
{
    // Input URLs
    NSArray *inputURLs = [self getInputURLsWithTitle:@"Choose Project File(s)/Folder"];
    
    // Get Only Source Files
    NSMutableArray *sourceFiles = [NSMutableArray array];
    for (int i = 0; i < [inputURLs count]; i++) {
        NSURL *fileURL = [inputURLs objectAtIndex:i];
        
        NSArray *matches = [self sourceFilesFromURL:fileURL];
        
        if (matches.count) {
            [sourceFiles addObjectsFromArray:matches];
        }
    }
    
    // Get Existing Strings files
    NSMutableArray *stringsFiles = [NSMutableArray array];
    for (int i = 0; i < [inputURLs count]; i++) {
        NSURL *fileURL = [inputURLs objectAtIndex:i];
        
        NSArray *matches = [self localizationFilesFromURL:fileURL];
        
        if (matches.count) {
            [stringsFiles addObjectsFromArray:matches];
        }
    }
    
    // Get Outout location
    NSURL *outputURL = [self getDestinationPathWithTitle:@"Choose Output Folder"];
    
    if (sourceFiles.count && outputURL) {
        NSArray *strings = [self localizationStringsFromFiles:sourceFiles];
        
        NSArray *uniqueStrings = [self uniqueStringsFromArray:strings];
        
        NSString *formattedString = [self formattedStringFromStrings:uniqueStrings];
        
        [self createExcelFilesFromString:formattedString existingFiles:stringsFiles destinationURL:outputURL];
    }
    
    NSAlert *alert = [NSAlert alertWithMessageText:@"Export Complete" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Your excel files have been created at the location specified."];
    [alert runModal];
}


#pragma mark - Localization Methods

- (NSArray *)localizationStringsFromFiles:(NSArray *)files
{
    NSRegularExpression *commentRegex = [NSRegularExpression
                                         regularExpressionWithPattern:@"NSLocalizedString\\(@\"([^\"]*)\",\\s*@\"([^\"]*)\"\\s*\\)"
                                         options:0
                                         error:nil];
    
    NSRegularExpression *nilRegex = [NSRegularExpression
                                     regularExpressionWithPattern:@"NSLocalizedString\\(@\"([^\"]*)\",\\s*nil\\s*\\)"
                                     options:0
                                     error:nil];
    
    NSRegularExpression *customRegex = [NSRegularExpression
                                        regularExpressionWithPattern:@"Localized\\(@\"([^\"]*)\"\\s*\\)"
                                        options:0
                                        error:nil];
    
    NSMutableArray *stringsArray = [NSMutableArray array];
    
    for (NSURL *url in files) {
        NSString *fileContents = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        
        [commentRegex enumerateMatchesInString:fileContents options:0 range:NSMakeRange(0, [fileContents length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
            if (match.numberOfRanges == 3) {
                [stringsArray addObject:@[[fileContents substringWithRange:[match rangeAtIndex:1]],
                                          [fileContents substringWithRange:[match rangeAtIndex:2]],
                                          url.lastPathComponent,
                                          @NO]];
                
            }
        }];
        
        [nilRegex enumerateMatchesInString:fileContents options:0 range:NSMakeRange(0, [fileContents length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
            if (match.numberOfRanges == 2) {
                [stringsArray addObject:@[[fileContents substringWithRange:[match rangeAtIndex:1]],
                                          @"",
                                          url.lastPathComponent,
                                          @NO]];
                
            }
        }];
        
        [customRegex enumerateMatchesInString:fileContents options:0 range:NSMakeRange(0, [fileContents length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
            if (match.numberOfRanges == 2) {
                [stringsArray addObject:@[[fileContents substringWithRange:[match rangeAtIndex:1]],
                                          @"",
                                          url.lastPathComponent,
                                          @NO]];
                
            }
        }];
    }
    
    return stringsArray;
}

- (NSString *)formattedStringFromStrings:(NSArray *)strings
{
    NSString *outputString = @"";
    
    NSMutableArray *duplicateArray = [NSMutableArray array];
    
    NSMutableDictionary *stringsDict = [NSMutableDictionary dictionary];
    
    for (NSArray *array in strings) {
        if ([array[3] boolValue]) {
            [duplicateArray addObject:array];
        }
        else {
            NSMutableArray *fileArray = stringsDict[array[2]];
            if (!fileArray) {
                fileArray = [NSMutableArray array];
                stringsDict[array[2]] = fileArray;
            }
            
            [fileArray addObject:array];
        }
    }
    
    NSMutableArray *keys = [[stringsDict allKeys] mutableCopy];
    [keys sortUsingSelector:@selector(caseInsensitiveCompare:)];
    
    for (NSString *key in keys) {
        outputString = [NSString stringWithFormat:@"%@/* %@ */\n", outputString, key];
        
        NSArray *array = stringsDict[key];
        
        for (strings in array) {
            if ([strings[1] length])
                outputString = [NSString stringWithFormat:@"%@// %@\n", outputString, strings[1]];
            
            outputString = [NSString stringWithFormat:@"%@\"%@\" = \"%@\";\n", outputString, strings[0], strings[0]];
        }
        
        outputString = [outputString stringByAppendingString:@"\n"];
    }
    
    outputString = [NSString stringWithFormat:@"%@\n/* SHARED STRINGS */\n", outputString];
    
    for (strings in duplicateArray) {
        if ([strings[1] length])
            outputString = [NSString stringWithFormat:@"%@// %@\n", outputString, strings[1]];
        
        outputString = [NSString stringWithFormat:@"%@\"%@\" = \"%@\";\n", outputString, strings[0], strings[0]];
    }
    
    return outputString;
}

- (void)createExcelFilesFromString:(NSString *)string
                     existingFiles:(NSArray *)existingFiles
                    destinationURL:(NSURL *)destinationURL
{
    Py_SetProgramName("/usr/bin/python");
    
    Py_Initialize();
    
    if (existingFiles && existingFiles.count) {
        for (NSURL *url in existingFiles) {
            char *argv[4];
            argv[0] = "GenerateCombinedFiles.py";
            argv[1] = (char*)[destinationURL.path UTF8String];
            argv[2] = (char*)[string UTF8String];
            argv[3] = (char*)[[url path] UTF8String];
            
            int argc = 4;
            
            PySys_SetArgv(argc, argv);
            
            NSString *scriptPath = [self.bundle pathForResource:@"GenerateCombinedFiles"
                                                         ofType:@"py"];
            PyObject *PyFileObject = PyFile_FromString((char*)[scriptPath UTF8String], "r");
            
            PyRun_SimpleFile(PyFile_AsFile(PyFileObject), "GenerateCombinedFiles.py");
        }
    }
    else {
        char *argv[3];
        argv[0] = "GenerateCombinedFiles.py";
        argv[1] = (char*)[destinationURL.path UTF8String];
        argv[2] = (char*)[string UTF8String];
        
        int argc = 3;
        
        PySys_SetArgv(argc, argv);
        
        NSString *scriptPath = [self.bundle pathForResource:@"GenerateCombinedFiles"
                                                     ofType:@"py"];
        PyObject *PyFileObject = PyFile_FromString((char*)[scriptPath UTF8String], "r");
        
        PyRun_SimpleFile(PyFile_AsFile(PyFileObject), "GenerateCombinedFiles.py");
    }
    
    NSLog(@"Done Creating Files");
    Py_Finalize();
}

- (void)importExcelFilesAtURL:(NSURL *)excelURL
                toStringsFile:(NSURL *)stringsURL
{
    Py_SetProgramName("/usr/bin/python");
    
    Py_Initialize();
    
    if (excelURL && stringsURL) {
        char *argv[3];
        argv[0] = "ImportExcelFile.py";
        argv[1] = (char*)[stringsURL.path UTF8String];
        argv[2] = (char*)[excelURL.path UTF8String];
        
        int argc = 3;
        
        PySys_SetArgv(argc, argv);
        
        NSString *scriptPath = [self.bundle pathForResource:@"ImportExcelFile"
                                                     ofType:@"py"];
        PyObject *PyFileObject = PyFile_FromString((char*)[scriptPath UTF8String], "r");
        
        PyRun_SimpleFile(PyFile_AsFile(PyFileObject), "ImportExcelFile.py");
    }
    
    NSLog(@"Done Importing Files");
    Py_Finalize();
}


#pragma mark - Helper Methods

- (NSArray *)uniqueStringsFromArray:(NSArray *)allStrings
{
    NSMutableArray *uniqueArray = [NSMutableArray array];
    
    NSMutableArray *alreadyChecked = [NSMutableArray array];
    
    for (NSArray *currentArray in allStrings) {
        if (![alreadyChecked containsObject:currentArray]) {
            
            NSMutableArray *editedArray = [currentArray mutableCopy];
            
            for (NSArray *checkArray in allStrings) {
                if (currentArray != checkArray) {
                    if ([currentArray[0] isEqualToString:checkArray[0]]) {
                        [alreadyChecked addObject:checkArray];
                        
                        if (![currentArray[1] isEqualToString:checkArray[1]]) {
                            editedArray[1] = [NSString stringWithFormat:@"%@, %@", editedArray[1], checkArray[1]];
                        }
                        
                        if (![currentArray[2] isEqualToString:checkArray[2]]) {
                            editedArray[2] = [NSString stringWithFormat:@"%@, %@", editedArray[2], checkArray[2]];
                            
                            editedArray[3] = @YES;
                        }
                    }
                }
            }
            [uniqueArray addObject:editedArray];
        }
    }
    
    return uniqueArray;
}

- (NSArray *)recursiveURLsForResourcesOfType:(NSArray *)extensions atURL:(NSURL *)url
{
	NSMutableArray *filePaths = [[NSMutableArray alloc] init];
    
    NSNumber *isDir;
    
    [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
    
    if ([isDir boolValue]) {
        // Enumerators are recursive
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:url includingPropertiesForKeys:[NSArray array] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
        
        for (NSURL *theURL in enumerator) {
            for (NSString *extension in extensions) {
                if ([[theURL pathExtension] isEqualToString:extension]) {
                    [filePaths addObject:theURL];
                    break;
                }
            }
        }
    }
    else {
        [filePaths addObject:url];
    }
    
	return filePaths;
}

- (NSString *)fileLanguageAbbreviationForString:(NSString *)inputstring
{
    NSArray *components = [inputstring componentsSeparatedByString:@"-"];
    NSString *retValue = [components objectAtIndex:components.count-1];
    
    NSArray *components2 = [retValue componentsSeparatedByString:@"."];
    return  [components2 objectAtIndex:0];
}

- (NSString *)folderLanguageAbbreviationForString:(NSString *)inputstring
{
    NSArray *components = [inputstring componentsSeparatedByString:@"/"];
    NSString *retValue = [components objectAtIndex:components.count-2];
    
    NSArray *components2 = [retValue componentsSeparatedByString:@"."];
    return  [components2 objectAtIndex:0];
}

- (NSURL *)currentWorkspaceURL
{
    NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") valueForKey:@"workspaceWindowControllers"];
    
    id workSpace;
    
    for (id controller in workspaceWindowControllers) {
        if ([[controller valueForKey:@"window"] isEqual:[NSApp keyWindow]]) {
            workSpace = [controller valueForKey:@"_workspace"];
        }
    }
    
    NSString *workspacePath = [[workSpace valueForKey:@"representingFilePath"] valueForKey:@"_pathString"];
    
    NSURL *pathURL = [[NSURL fileURLWithPath:workspacePath] URLByDeletingPathExtension];
    
    return pathURL;
}

- (NSArray *)sourceFilesFromURL:(NSURL *)url
{
    return [self recursiveURLsForResourcesOfType:@[@"h", @"m"] atURL:url];
}

- (NSArray *)excelFilesFromURL:(NSURL *)url
{
    return [self recursiveURLsForResourcesOfType:@[@"xls"] atURL:url];
}

- (NSArray *)localizationFilesFromURL:(NSURL *)url
{
    NSMutableArray *matchingStrings = [[self recursiveURLsForResourcesOfType:@[@"strings"] atURL:url] mutableCopy];
    
    NSMutableArray *existing = [NSMutableArray array];
    
    for (NSURL *url in matchingStrings) {
        if ([url.lastPathComponent isEqualToString:@"Localizable.strings"])
            [existing addObject:url];
    }
    
    return existing;
}

@end
