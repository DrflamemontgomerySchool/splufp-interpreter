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
      default:
        return 'Undefined';
    }
  }

  public static function main() {
    final test_string = "   let set";

    Lambda.map(parser.Lexer.parse(test_string + '\n'), printExpr);
  }
}
