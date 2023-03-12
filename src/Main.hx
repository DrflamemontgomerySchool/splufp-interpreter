package;

import parser.Lexer.Lexer;
import parser.Lexer.LexExpr;

using Lambda;

class Main {
  static var fileOut = 'out.js';

  static function joinFileString(filename:String, result:String) : String {
    switch(filename) {
      case s if(~/^--out=/.match(s)):
        fileOut = ~/^--out=/.replace(s, '');
        return result;
      case s if(!sys.FileSystem.exists(filename)):
        throw '\'${filename}\' is not a valid file name';
      case s:
        return '${result}${sys.io.File.getContent(s)}\n';
    }
  }

  static function copyDirectory(src:String, dest:String) {
    if(sys.FileSystem.exists(src)) {
      sys.FileSystem.createDirectory(dest);
      for(file in sys.FileSystem.readDirectory(src)) {
        var path = haxe.io.Path.join([src, file]);
        var dpath = haxe.io.Path.join([dest, file]);

        if(sys.FileSystem.isDirectory(path)) {
          copyDirectory(path, dpath);
        }
        else {
          sys.io.File.saveContent(dpath, '');
          sys.io.File.copy(path, dpath);
        }
      }
    }
  }

  public static function main() {
  
    final cur_path = haxe.io.Path.directory(Sys.programPath());
    if(Sys.args().length <= 0) {
      Sys.println('usage: splufp-compiler init_project');
      Sys.println('usage: splufp-compiler [--out=filename] program-files...');
      return;
    }

    switch(Sys.args()[0]) {
      case 'init_project':
        copyDirectory('${cur_path}/spl-extern', 'spl-extern');
        return; 
    }

    final paths = ['${cur_path}/spl/splufp-base.spl'].concat(Sys.args());

    final content = paths.fold(joinFileString, '');
    sys.io.File.saveContent(fileOut, Transpiler.transpile(parser.Lexer.parse(content)));
  
  }
}
