package;

import parser.Lexer.LexExpr;

using Lambda;

class Transpiler {

  // Helper function for transpiling an AST
  public static function transpile(expressions : Array<LexExpr> ) {
    return new Transpiler(expressions).doTranspile();
  }

  function new(expressions : Array<LexExpr> ) {
    exprs = expressions;
  }

  var exprs : Array<LexExpr>;
  

  // Make a JavaScript expression from a Splufp Function Expression
  function functionExprToJS(expr:LexExpr, result:String) : String {
    return result + exprToJavascript(expr) + ';';
  }

  // Iterate over all function expressions to create
  // JavaScript expressions
  function functionBodyToJS(body:Array<LexExpr>) : String {
    return '${body.splice(0, body.length-1).fold(functionExprToJS, '')} return ${exprToJavascript(body[body.length-1])};';
  }

  // Iterate over all the 
  function externArgsToJS(args:Array<String>) : String {
    if(args.length > 1) {
      return '${args[0]}.call()' + ',' + externArgsToJS(args.splice(1, args.length-1));
    } else if(args.length > 0) {
      return '${args[0]}.call()';
    }
    return '';
  }

  // Create a function from a Splufp Function Expression
  function functionToJS(args:Array<String>, body:Array<LexExpr>, arg_length:Int) {
    if(args.length > 1) {
      return 'function(__spl__${args[0]}) { return ' + functionToJS(args.splice(1, args.length-1), body, arg_length) + '; }';
    }
    else if(args.length > 0) {
      return 'function(__spl__${args[0]}) { ${functionBodyToJS(body)}; }';
    }
    return functionBodyToJS(body);
  }

  // Function for creating the args inside an
  // External JavaScript Function that has
  // a defined profile
  function fullArgsToJSArgs(args:Array<String>) : String {
    if(args.length > 1) {
      return '${args[0]}, ${fullArgsToJSArgs(args.copy().splice(1, args.length-1))}';
    }
    if(args.length > 0) {
      return '${args[0]}';
    }
    return '';
  }


  // Function for creating the args inside an
  // External JavaScript Function that has
  // no defined profile
  function fullArgsToJSSplufpCalls(args:Array<String>) : String {
    if(args.length > 1) {
      return '__spl__${args[0]}.call(), ${fullArgsToJSSplufpCalls(args.copy().splice(1, args.length-1))}';
    }
    if(args.length > 0) {
      return '__spl__${args[0]}.call()';
    }
    return '';
  }

  // Create an Extern Function from
  // a Splufp ExternJS Expression
  function externToJS(name:String, args:Array<String>, full_args:Array<String>, profile:Null<String>) : String {
    if(args.length > 0) {
      return 'function(__spl__${args[0]}) { return ' + externToJS(name, args.copy().splice(1, args.length-1), full_args, profile) + '; }';
    }

    if(profile == null) {
      return '${name}(${fullArgsToJSSplufpCalls(full_args)})';
    }
    
    return 'function(${fullArgsToJSArgs(full_args)}) { return ${profile}; }(${fullArgsToJSSplufpCalls(full_args)})';
  }

  // Create a JavaScript Map from a
  // Splufp Object Expression
  function objectToJS(map:Map<String, LexExpr>) : String {
    var str = '{ ';
    for(key in map.keys()) {
      str += '"$key" : ${exprToJavascript(map[key])},';
    }

    return str.substring(0, str.length-1) + ' }';
  }

  // Create a Function Call from a list
  // of Arguments
  function callsToJS(args:Array<LexExpr>) : String {
    var calls = '';
    for(i in args) {
      calls += '(${callArgToJS(i)})';
    }
    return calls;
  }
  
  // Create a Splufp Data Type from a
  // Call Argument
  function callArgToJS(expr:LexExpr) : String {
    switch(expr) {
      case LexCall(name, args) if(args.length == 0):
        return '__spl__${name}';
      case _:
        return 'new __splufp__function(${exprToJavascript(expr)})';
    }
  }

  // Helper function for iterating
  // over all the Splufp expressions
  function __exprToJavascript(expr : LexExpr, result : String) : String {
    return '$result\n${exprToJavascript(expr)}';
  }

  // Convert a Splufp Expression
  // to JavaScript code
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
            return 'const __spl__$name = new __splufp__function(${exprToJavascript(body[0])});'; 
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

  // Function to transpile expressions
  // and return JavaScript code in a string
  function doTranspile() : String {
    return exprs.fold(__exprToJavascript, "");  
  }

}
