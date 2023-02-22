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

  public static function main() {
  
  if(Sys.args().length <= 0) {
    Sys.println('usage: splufp-compiler [--out=filename] program-files...');
    return;
  }
  final content = Sys.args().fold(joinFileString, '');
  sys.io.File.saveContent(fileOut, Transpiler.transpile(parser.Lexer.parse(content)));
  
  }
}
