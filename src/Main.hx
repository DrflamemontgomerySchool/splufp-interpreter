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

  public static function main() {
    final test_string = "
let one = -12.32\n
set two = true\n
let a = [null, true, false, 1, -1, .01, -.01, '123\t123', [1, 2, 3] ]
let b = one\n
let c = { a : 1.12, b:'123', c : { a : 123, b : true } }
let d = func_name 1 2 3
func_name a b c {
  (a (add 1 2 (neg 3)))
  add 1
  2
  '123'
  123
  let a = \\(a b c\\) {
  }
}

externjs test_js a b c
";

    //Lambda.map(parser.Lexer.parse(test_string + '\n'), printExpr);
#if js
  js.Browser.console.log(Transpiler.getJavascriptHeader() + Transpiler.transpile(parser.Lexer.parse(test_string + '\n')));
#else
  Std.printLn(Transpiler.transpile(parser.Lexer.parse(test_string + '\n')));
#end
  }
}
