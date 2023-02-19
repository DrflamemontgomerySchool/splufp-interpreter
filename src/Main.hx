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
        return '$name $args';

      case LexFunction(type, name, args, body):
        switch(type) {
          case ConstantVariable:
            return 'let $name = ${ (body.length == 0 ? 'void' : exprToString(body[0]) ) }';
          case NonConstantVariable:
            return 'set $name = ${ (body.length == 0 ? 'void' : exprToString(body[0]) ) }';
          case Function:
            return 'function $name ${['\n'].concat([ for(i in body) '\x08  ' + exprToString(i) + '\n'])}';
        }

      default:
        return 'Undefined';
    }
  }

  public static function main() {
    final test_string = "
let one = -12.32\n
set two = true\n
let a = [null, true, false, 1, -1, .01, -.01, '123\t123', [1, 2, 3] ]
let b = 'test'
let a = { a : 1.12, b:'123', c : { a : 123, b : true } }
func_name a b c {
  123
  let a = 2
}
//let b = 123
";

    Lambda.map(parser.Lexer.parse(test_string + '\n'), printExpr);
  }
}
