package;

import parser.Lexer.Lexer;
import parser.Lexer.LexExpr;

using Lambda;

class Main {

  static inline function printToConsole(s:String) {
#if js
    js.Browser.console.log(s);
#else
    Sys.println(s);
#end
  }

  static function printExpr(expr:LexExpr) {
    printToConsole(exprToString(expr));
    return '';
  }

  public static function exprToString(expr:LexExpr) : String {
    switch(expr) {
      case LexNull:
        return 'null';

      case LexBool(t):
        return '$t';

      case LexNumber(n):
        return '$n';

      case LexString(s):
        return '"$s"';

      case LexArray(arr):
        var str = [ for(i in arr) exprToString(i) ];
        return '$str';

      case LexObject(map):
        var str = [ for(i in map.keys()) '$i : ${exprToString(map[i])}' ];
        return '$str';

      case LexCall(name, args):
        return '$name ${[for(i in args) exprToString(i)]}';

      case LexExternJS(name, args):
        return 'externjs ${name} ${args}';

      case LexFunction(type, name, args, body):
        switch(type) {
          case ConstantVariable:
            return 'let $name = ${ (body.length == 0 ? 'void' : exprToString(body[0]) ) }';
          case NonConstantVariable:
            return 'set $name = ${ (body.length == 0 ? 'void' : exprToString(body[0]) ) }';
          case Function:
            return 'function $name $args ${['\n'].concat([ for(i in body) '\x08  ' + exprToString(i) + '\n'])}';
        }
      case LexLambda(args, body):
        return 'lambda $args ${['\n'].concat([ for(i in body) '\x08  ' + exprToString(i) + '\n'])}';

      default:
        return 'Undefined';
    }
  }

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
    final test_string = "
externjs add a b
externjs sub a b
externjs mul a b
externjs div a b
externjs neg a
externjs array_at arr n
externjs obj_get obj name


let one = -12.32\n
set two = true\n
let a = [null, true, false, 1, -1, .01, -.01, '123\t123', [1, 2, 3] ]
let b = one\n
let c = { a : 1.12, b:'123', c : { a : 123, b : true } }

test_func {
  set a = 12
  a = 10 
  a
}

  ";
  
  if(Sys.args().length <= 0) {
    printToConsole('usage: splufp-compiler [--out=filename] program-files...');
    return;
  }
  final content = Sys.args().fold(joinFileString, '');
  sys.io.File.saveContent(fileOut, Transpiler.transpile(parser.Lexer.parse(content)));
  
  //var program_string = '';

  /*for(arg in Sys.args()) {
    printToConsole(arg);
  }*/

//printToConsole(Transpiler.transpile(parser.Lexer.parse(test_string + '\n')));
  }
}
