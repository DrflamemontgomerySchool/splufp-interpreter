package;

import parser.Lexer.LexExpr;
import parser.Lexer.FuncType;
using Lambda;

class Transpiler {

  // Helper function for transpiling an AST
  public static function transpile(expressions : Array<LexExpr> ) : String {
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
    return '${
      body.splice(0, body.length-1).fold(functionExprToJS, '')
    } return ${
      exprToJavascript(body[body.length-1])
    };';
  }

  // Iterate over all the external JavaScript arguments
  // and parse the value into the argument
  function externArgsToJS(args:Array<String>) : String {
    if(args.length > 1) {
      return '${args[0]}.call()' + ',' + externArgsToJS(args.splice(1, args.length - 1));
    } else if(args.length > 0) {
      return '${args[0]}.call()';
    }
    return '';
  }

  // Create a function from a Splufp Function Expression
  function functionToJS(args:Array<String>, body:Array<LexExpr>, argLength:Int) : String {
    if(args.length > 1) {
      return 'function(__spl__${args[0]}) { return '
        + functionToJS(args.splice(1, args.length - 1), body, argLength)
        + '; }';
    } else if(args.length > 0) {
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
  function externToJS(name:String, args:Array<String>, fullArgs:Array<String>, profile:Null<String>) : String {
    if(args.length > 0) {
      return 'function(__spl__${args[0]}) { return '
        + externToJS(name, args.copy().splice(1, args.length - 1), fullArgs, profile)
        + '; }';
    }

    if(profile == null) {
      return '${name}(${fullArgsToJSSplufpCalls(fullArgs)})';
    }

    return 'function(${fullArgsToJSArgs(fullArgs)}) { return ${profile}; }(${fullArgsToJSSplufpCalls(fullArgs)})';
  }

  // Create a JavaScript Map from a
  // Splufp Object Expression
  function objectToString(map:Map<String, LexExpr>) : String {
    var str = '{ ';
    for(key in map.keys()) {
      str += '"$key" : ${exprToJavascript(map[key])},';
    }

    return str.substring(0, str.length - 1) + ' }';
  }

  // Create a Function Call from a list
  // of Arguments
  function callsToJS(args:Array<LexExpr>) : String {
    var calls = '';
    for(arg in args) {
      calls += '(${callArgToJS(arg)})';
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

      case LexBool(isTrue):
        return '$isTrue';

      case LexNumber(number):
        return '$number';

      case LexString(stringVal):
        return '"$stringVal"';

      case LexArray(array):
        return arrayToString(array);

      case LexObject(map):
        return objectToString(map);

      case LexCall(name, args):
        return callToString(name, args);

      case LexAssignment(name, val):
        return assignmentToString(name, val);

      case LexExternJS(name, args, profile):
        return externToString(name, args, profile);

      case LexLambda(args, body):
        return lambdaToString(args, body);

      case LexFunction(type, name, args, body):
        return functionOrVariableToString(type, name, args, body);

      case LexIf(condition, ifBody, elseBody):
        return ifToString(condition, ifBody, elseBody);

      case LexWhile(condition, body):
        return whileToString(condition, body);

      case _:
        return '';
    }
  }

  // Helper function for turning an array into a JavaScript string
  inline function arrayToString(array : Array<LexExpr>) : String {
    return '${[for(elem in array) exprToJavascript(elem)]}';
  }

  // Helper function for turning a function call into a JavaScript string
  inline function callToString(name : String, args : Array<LexExpr>) : String {
    switch(name) {
      case 'ret':
        return 'return ${callsToJS(args)}.call()';
      case _:
        return '__spl__$name.call()${callsToJS(args)}';
    }
  }

  // Helper function for turning a variable assignment into a JavaScript string
  inline function assignmentToString(name : String, val : LexExpr) : String {
    return '__spl__$name.set_value(${exprToJavascript(val)})';
  }

  // Helper function for turning an external JavaScript function into a JavaScript string
  inline function externToString(name : String, args : Array<String>, profile : String) : String {
    if(args.length > 0) {
      return 'const __spl__'
        + name
        + ' = new __splufp__function(function() {'
        + ' return ${externToJS(name, args, args, profile)};'
        + '});';
    }
    return 'const __spl__$name = new __splufp__function(function() { ${externToJS(name, args, args, profile)};});';
  }

  // Helper function for turning a lambda into a JavaScript string
  inline function lambdaToString(args : Array<String>, body : Array<LexExpr>) : String {
    if(args.length > 0) {
      return 'function(){ return ${functionToJS(args, body, args.length)};}';
    }
    return 'function(){ ${functionToJS(args, body, args.length)};}';
  }

  // Helper function for turning a if statement into a JavaScript string
  inline function ifToString(condition : LexExpr, ifBody : Array<LexExpr>, elseBody : Array<LexExpr>) : String {
    return 'if(${exprToJavascript(condition)}) {'
      + '${ifBody.fold(functionExprToJS, '')}}'
      + 'else {${elseBody.fold(functionExprToJS, '')}}';
  }

  // Helper function for turning a while statement into a JavaScript string
  inline function whileToString(condition : LexExpr, body : Array<LexExpr>) : String {
    return 'while(${exprToJavascript(condition)}) {${body.fold(functionExprToJS, '')}}';
  }

  // Helper function for turning a function or variable into a JavaScript string
  inline function functionOrVariableToString(
      type : FuncType,
      name : String,
      args : Array<String>,
      body : Array<LexExpr>
  ) : String  {
    switch(type) {
      case ConstantVariable:
        return constantVariableToString(name, body);
      case NonConstantVariable:
        return nonConstantVariableToString(name, body);
      case Function:
        return functionToString(name, args, body);
    }
  }

  // Helper function for turning a constant variable into a JavaScript string
  inline function constantVariableToString(name : String, body : Array<LexExpr>) : String {
    return 'const __spl__$name = new __splufp__function(${exprToJavascript(body[0])});';
  }

  // Helper function for turning a non-constant variable into a JavaScript string
  inline function nonConstantVariableToString(name : String, body : Array<LexExpr>) : String {
    return 'var __spl__$name = new __splufp__function_assignable(${exprToJavascript(body[0])});';
  }

  // Helper function for turning a function variable into a JavaScript string
  inline function functionToString(name : String, args : Array<String>, body : Array<LexExpr>) : String {
    if(args.length > 0) {
      return 'const __spl__'
        + name
        + ' = new __splufp__function(function(){'
        + ' return ${functionToJS(args, body, args.length)};'
        + '});';
    }
    return 'const __spl__'
      + name
      + ' = new __splufp__function(function(){'
      + ' ${functionToJS(args, body, args.length)};'
      + '});';
  }

  // Function to transpile expressions
  // and return JavaScript code in a string
  function doTranspile() : String {
    return exprs.fold(__exprToJavascript, '');
  }
}
