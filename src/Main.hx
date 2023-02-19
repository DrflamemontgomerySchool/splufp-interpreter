package;

import parser.Lexer.Lexer;
import parser.Lexer.LexExpr;

class Main {

  static function printExpr(expr:LexExpr) {
#if js
    js.Browser.console.log(exprToString(expr));
#else
    Std.printLn(exprToString(expr));
#end
    return '';
  }

  static function exprToString(expr:LexExpr) : String {
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

      case LexCall(name, args):
        return '$name $args';

      case LexFunction(type, name, args, body):
        switch(type) {
          case ConstantVariable:
            return 'let $name = ${ (body.length == 0 ? 'void' : exprToString(body[0]) ) }';
          case NonConstantVariable:
            return 'set $name = ${ (body.length == 0 ? 'void' : exprToString(body[0]) ) }';
          case Function:
            return 'Function not implemented';
        }

      default:
        return 'Undefined';
    }
  }

  public static function main() {
    final test_string = "
let one = -12.32\n
set two = true\n
let a = [[123, 234], []]
let b = 'test'
//let a = { a : 1.12 }
//let b = 123
";

    Lambda.map(parser.Lexer.parse(test_string + '\n'), printExpr);
  }
}
