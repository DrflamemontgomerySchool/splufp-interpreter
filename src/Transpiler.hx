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
    return '${exprToJavascript(body[0])}';
  }

  function functionExprToJS(expr:LexExpr, result:String) : String {
    return result + exprToJavascript(expr) + ';';
  }

  function functionBodyToJS(body:Array<LexExpr>) : String {
    return '${body.splice(0, body.length-1).fold(functionExprToJS, '')} return ${exprToJavascript(body[body.length-1])};';
  }

  function externArgsToJS(args:Array<String>) : String {
    if(args.length > 1) {
      return '${args[0]}.call()' + ',' + externArgsToJS(args.splice(1, args.length-1));
    } else if(args.length > 0) {
      return '${args[0]}.call()';
    }
    return '';
  }


  function functionToJS(args:Array<String>, body:Array<LexExpr>, arg_length:Int) {
    /*if(arg_length == 0) {
      return 'function() {${functionBodyToJS(body)}}';
    }*/

    if(args.length > 1) {
      return 'function(__spl__${args[0]}) { return ' + functionToJS(args.splice(1, args.length-1), body, arg_length) + '; }';
    }
    else if(args.length > 0) {
      return 'function(__spl__${args[0]}) { ${functionBodyToJS(body)}; }';
    }
    return functionBodyToJS(body);
  }

  function fullArgsToJSArgs(args:Array<String>) : String {
    if(args.length > 1) {
      return '${args[0]}, ${fullArgsToJSArgs(args.copy().splice(1, args.length-1))}';
    }
    if(args.length > 0) {
      return '${args[0]}';
    }
    return '';
  }

  function fullArgsToJSSplufpCalls(args:Array<String>) : String {
    if(args.length > 1) {
      return '__spl__${args[0]}.call(), ${fullArgsToJSSplufpCalls(args.copy().splice(1, args.length-1))}';
    }
    if(args.length > 0) {
      return '__spl__${args[0]}.call()';
    }
    return '';
  }

  function externToJS(name:String, args:Array<String>, full_args:Array<String>, profile:Null<String>) : String {
    if(args.length > 0) {
      return 'function(__spl__${args[0]}) { return ' + externToJS(name, args.copy().splice(1, args.length-1), full_args, profile) + '; }';
    }

    if(profile == null) {
      return '${name}(${fullArgsToJSSplufpCalls(full_args)})';
    }
    
    return 'function(${fullArgsToJSArgs(full_args)}) { return ${profile}; }(${fullArgsToJSSplufpCalls(full_args)})';
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
      calls += '(${callArgToJS(i)})';
    }
    return calls;
  }
  
  function callArgToJS(expr:LexExpr) : String {
    switch(expr) {
      case LexCall(name, args) if(args.length == 0):
        return '__spl__${name}';
      case _:
        return 'new __splufp__function(${exprToJavascript(expr)})';
    }
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
        switch(name) {
          case 'ret':
            return 'return ${callsToJS(args)}.call()';
          case _:
            return '__spl__$name.call()${callsToJS(args)}';
        }

      case LexAssignment(name, val):
        return '__spl__$name.set_value(${exprToJavascript(val)})';

      case LexExternJS(name, args, profile):
        if(args.length > 0) {
          return 'const __spl__$name = new __splufp__function(function() { return ${externToJS(name, args, args, profile)};});';
        }
        return 'const __spl__$name = new __splufp__function(function() { ${externToJS(name, args, args, profile)};});';
  
      case LexLambda(args, body):
        if(args.length > 0) {
          return 'function(){ return ${functionToJS(args, body, args.length)};}';
        }
        return 'function(){ ${functionToJS(args, body, args.length)};}';


      case LexFunction(type, name, args, body):
        switch(type) {
          case ConstantVariable:
            return 'const __spl__$name = new __splufp__function(${variableBodyToJS(body)});'; 
          case NonConstantVariable:
            return 'var __spl__$name = new __splufp__function_assignable(${exprToJavascript(body[0])});'; 
          case Function:
            if(args.length > 0) {
              return 'const __spl__$name = new __splufp__function(function(){ return ${functionToJS(args, body, args.length)};});';
            }
            return 'const __spl__$name = new __splufp__function(function(){ ${functionToJS(args, body, args.length)};});';
        }
      case LexIf(condition, if_body, else_body):
        return 'if(${exprToJavascript(condition)}) {${if_body.fold(functionExprToJS, '')}} else {${else_body.fold(functionExprToJS, '')}}';

      case LexWhile(condition, body):
        return 'while(${exprToJavascript(condition)}) {${body.fold(functionExprToJS, '')}}'; 

      default:
        return '';

    }
    return "";
  }

  public function doTranspile() : String {
    return exprs.fold(__exprToJavascript, "");  
  }

}
