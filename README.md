ECLocalizerPlugin
=================

Xcode Plugin to generate localization files from project as xls. Can also import the translated files into strings files

To add plugin to Xcode:
Simply open the project, Build and run.
Close Xcode completely.
Reopen Xcode. You will see a new menu item under File called Localization.

How to use:
Once your project is using the NSLocalizationString Macro, select either 'Export Current Project' to search the entire project directory, or 'Export Selected Files' to manually choose which files to localize. This will produce xls file at the desired output location. Column A is the english key, and column B is the value to be translated.

Note: This tool will look for existing strings files and make sure to replace any matching key pairs in the xls file with the already translated string in it's matching file.

Once you are happy with your xls file(s), you can fold them back into .strings files in your project by selecting the 'Import Selected Files' menu item. This will allow you to choose which .xls files to import and also where to create the strings files.

Note: If there are already existing localization files at the output location this tool will replace them with the updated translations.
