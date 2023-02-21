package;

import parser.Lexer.LexExpr;

using Lambda;

class Transpiler {

  public static function transpile(expressions : Array<LexExpr> ) {
    return new Transpiler(expressions).doTranspile();
  }

  public function new(expressions : Array<LexExpr> ) {
    exprs = expressions;
  }

  var exprs : Array<LexExpr>;
  
  function variableBodyToJS(body:Array<LexExpr>) : String {
    return 'function() { return ${exprToJavascript(body[0])}; }';
  }

  function objectToJS(map:Map<String, LexExpr>) : String {
    var str = '{ ';
    for(key in map.keys()) {
      str += '"$key" : ${exprToJavascript(map[key])},';
    }

    return str.substring(0, str.length-1) + ' }';
  }

  function callsToJS(args:Array<LexExpr>) : String {
    var calls = '';
    for(i in args) {
      calls += '(${exprToJavascript(i)})';
    }
    return calls;
  }
    
  function __exprToJavascript(expr : LexExpr, result : String) : String {
    return '$result\n${exprToJavascript(expr)}';
  }

  function exprToJavascript(expr : LexExpr) : String {
    
    switch(expr) {
      case LexNull:
        return 'null';

      case LexBool(t):
        return '$t';

      case LexNumber(n):
        return '$n';

      case LexString(val):
        return '"$val"';

      case LexArray(arr):
        return '${[for(i in arr) exprToJavascript(i)]}';

      case LexObject(map):
        return objectToJS(map);

      case LexCall(name, args):
        return '__spl__$name.call()${callsToJS(args)}';

      case LexAssignment(name, val):
        return '__spl__$name = function() { return ${exprToJavascript(val)}; };';

      case LexExternJS(name, args):
        return 'const __spl__$name = function() {};';

      case LexFunction(type, name, args, body):
        switch(type) {
          case ConstantVariable:
            return 'const __spl__$name = new __splufp__function(${variableBodyToJS(body)});'; 
          case NonConstantVariable:
            return 'var __spl__$name = new __splufp__function_assignable(${exprToJavascript(body[0])});'; 
          case Function:
        }

      case c:
        return '';

    }
    return "";
  }

  public function doTranspile() : String {
    return exprs.fold(__exprToJavascript, "");  
  }

  public static function getJavascriptHeader() : String {
    return "
class __splufp__function {
  #value;
  constructor(value) {
    this._value = value;
  }

  call() {
    return this._value();
  }
}

class __splufp__function_assignable {
  #value;
  constructor(value) {
    this._value = value;
  }

  call() {
    return this._value;
  }

  set_value(value) {
    this._value = value;
  }
}
";
  }

}
