package parser;

enum FuncType {
  ConstantVariable;
  NonConstantVariable;
  Function;
}

// Enum containing all the different expressions that Splufp creates
enum LexExpr {
  LexNull;
  LexBool(val:Bool);
  LexNumber(val:Float);
  LexString(val:String);
  LexArray(val:Array<LexExpr>);
  LexObject(val:Map<String, LexExpr>);
  LexFunction(type:FuncType, name:String, args:Array<String>, body:Array<LexExpr>); // also variable
  LexLambda(args:Array<String>, body:Array<LexExpr>);
  LexCall(name:String, args:Array<LexExpr>);
  LexAssignment(name:String, val:LexExpr);
  LexExternJS(name:String, args:Array<String>, profile:Null<String>);
  LexIf(condition : LexExpr, ifBody : Array<LexExpr>, elseBody : Array<LexExpr>);
  LexWhile(condition : LexExpr, body : Array<LexExpr>);
}

// Valid Top Level Expressions:  
//  - Comment
//  - Variable Creation
//  - ExternalJS declaration
//  - Function Declaration

// Valid Function Expressions:
//  - Comment
//  - Control Statements
//  - Variable Creation
//  - Variable Assignment
//  - Function Call (referencing values also count)

class Lexer {

  // Helper function so that we don't have to create a new Lexer class every time
  public static inline function parse(fileStr:String) : Array<LexExpr> {
    return new Lexer(fileStr).doParse();
  }

  // Variables for file iteration
  var str:String;
  var pos:Int;
  var lastChar:Int;

  // Array of whitespace characters
  final whitespace : Array<Int> = [' '.code, '\t'.code, '\n'.code, '\r'.code];

  // Array of characters that variable names can start with
  final variableNameStart :Array<Int> = [
    for (char in 'a'.code...('z'.code + 1)) char
  ].concat([
      for (char in 'A'.code...('Z'.code + 1)) char
  ]).concat([
    '_'.code
  ]);

  // Array of characters that number can start with
  final numberStart : Array<Int> = [
    for(char in '0'.code...('9'.code + 1)) char
  ].concat([
      '-'.code, '.'.code
  ]);

  function new(str:String) {
    this.str = str;
    this.pos = 0;
  }

  //===============================================================---
  //   Parsing Functions
  //===============================================================---

  // Internal function for parsing the given string
  function doParse():Array<LexExpr> {
    // Abstract Syntax Tree
    var ast : Array<LexExpr> = [];

    while( true ) {
      switch(parseTopLevel()) {
        case null:
          return ast;
        case expr:
          ast.push( expr );
      }
    }
    return ast;
  }

  // Parses all the expressions that are at
  // the base of the program.
  function parseTopLevel() : Null<LexExpr> {
    var char : Int;
    while( !StringTools.isEof( (char = nextChar()) ) ) {
      lastChar = char;
      switch(char) {
        case _ if(whitespace.contains(char)):
          // loop
        case '/'.code:
          stripComment();
        case _ if( variableNameStart.contains(char) ):

          switch(getVariableName(char)) {
            case 'let':
              return parseVariableCreation(ConstantVariable);
            case 'set':
              return parseVariableCreation(NonConstantVariable);
            case 'externjs':
              return parseExternJS();
            case 'macro':
              // Macros are not implemented and are not planned to be implemented.
              throw 'macros are not implemented';
            case name:
              return LexFunction(Function, name, parseFunctionArgs(), parseFunctionBody());
          }
        case _:
          throw 'invalid top level expression \'${ toChar(char) }\' at pos: $pos';
      }
    }
    return null;
  }

  // Function for parsing external JavaScript functions
  function parseExternJS() : LexExpr {
    // Format for creating an externJs
    //
    // externjs func_name args
    // externjs func_name args 'javascript code'

    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code:
          // loop
        case _ if(variableNameStart.contains(lastChar)): // If it is a valid character for a variable
          final varName = getVariableName(lastChar); // Get the function name for the extern
          final args = parseFunctionArgs(); // Get the list of arguments

          // the profile is optional
          var profile = null;
          do {
            switch(lastChar) {
              case ' '.code, '\t'.code:
                // continue
              case "'".code, '"'.code:
                profile = parseString();
                break;
              case _:
                break;
            }
          } while( StringTools.isEof( (lastChar = nextChar()) ) );

          return LexExternJS(varName, args, profile);
        case _:
          throw 'expected extern expression, instead got\'${toChar(lastChar)}\'';
      }
    }

    throw 'expected externjs expression but reached EOF';
  }

  // Function for creating a constant or non-constant variable
  function parseVariableCreation(type : FuncType) : LexExpr {
    switch(lastChar) { // Make sure that we don't hit a new line or invalid character
      case ' '.code, '\t'.code:
      case str if( type == ConstantVariable ):
        'expected whitespace after \'let\', received \'$str\' instead';
      case str if( type == NonConstantVariable ):
        'expected whitespace after \'set\', received \'$str\' instead';
      case str:
        'variable type invalid';
    }

    // Hijack the assignment function because the function is the same

    switch(parseVariableAssignment() ) {
      case LexAssignment(name, val):
        return LexFunction(type, name, [], [val]);
      default:
        throw 'expected variable assignment';
    }
  }

  // Function for creating an expression of setting a variable with a value
  function parseVariableAssignment() : LexExpr {
    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code:
          // loop
        case '/'.code:
          stripComment();
        case _ if( variableNameStart.contains(lastChar) ): // do we have a valid variable name starting character?

          return LexAssignment(getVariableName(lastChar), parseVariableCreationBody());
        case str:
          throw 'expected variable name, received \'$str\' instead';
      }
    }

    throw 'expected variable expression but reached EOF';
  }

  // Returns the value of the variable creation if there is an '='
  function parseVariableCreationBody() : LexExpr {
    do {
      switch(lastChar) {
        case '/'.code:
          stripComment();
        case ' '.code, '\t'.code:
          // loop
        case '='.code:

          return parseVariableAssignmentExpr();
        case _:
          throw 'expected \'=\' after variable name, got \'${ toChar(lastChar) }';
      }
    } while( !StringTools.isEof( (lastChar = nextChar()) ) );

    throw 'expected variable expression but reached EOF';
  }

  // Parse the value of the variable
  function parseVariableAssignmentExpr() : LexExpr {
    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case '/'.code:
          stripComment();
        case ' '.code, '\t'.code:
          // loop
        case _ if (numberStart.contains(lastChar)):
          return LexNumber(parseNumberValue(lastChar));
        case '{'.code:
          return LexObject(parseObject());
        case '\\'.code:
          return parseLambda();
        case '('.code:
          return parseBracket();
        case '['.code:
          return LexArray(parseArray());
        case "'".code, '"'.code:
          return LexString(parseString());

        case _ if (variableNameStart.contains(lastChar)):
          return parseArrayVariableName(lastChar);

        case _:
          throw 'expected expression but got \'${toChar(lastChar)}\'';
      }
    }

    throw 'expected variable expression but reached EOF';
  }

  // Function that returns the correct
  function parseCallArgs() : Array<LexExpr> {
    var args : Array<LexExpr> = [];

    do {
      switch(lastChar) {
        case '='.code:
          return [LexAssignment('', parseVariableAssignmentExpr())];
        case '/'.code:
          stripComment();
          continue;
        case ' '.code, '\t'.code:
          // loop
          continue;
        case _ if (numberStart.contains(lastChar)):
          args.push( LexNumber(parseNumberValue(lastChar)) );
        case '{'.code:
          args.push( LexObject(parseObject()) );
          lastChar = nextChar();
        case '\\'.code:
          args.push( parseLambda() );
          lastChar = nextChar();
        case '('.code:
          args.push(parseBracket());
          lastChar = nextChar();
        case '['.code:
          args.push( LexArray(parseArray()) );
          lastChar = nextChar();
        case "'".code, '"'.code:
          args.push( LexString(parseString()) );
          lastChar = nextChar();

        case _ if (variableNameStart.contains(lastChar)):
          switch(getVariableName(lastChar)) {
            case 'true':
              args.push( LexBool(true) );
            case 'false':
              args.push( LexBool(false) );
            case 'null':
              args.push( LexNull );
            case str:
              args.push( LexCall(str, []) );
          }

        case _:
          return args;
      }
      pos--;
    } while( !StringTools.isEof( (lastChar = nextChar()) ) );

    throw 'expected function call arguments but reached EOF';
  }

  // Parse expressions that are contained within brackets
  function parseBracket() : LexExpr {
    var expr : LexExpr = LexNull;

    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case '/'.code:
          stripComment();
          continue;
        case ' '.code, '\t'.code:
          continue;
          // loop
        case _ if (numberStart.contains(lastChar)):
          expr = LexNumber(parseNumberValue(lastChar));
        case '{'.code:
          expr = LexObject(parseObject());
        case '\\'.code:
          return parseLambda();
        case '('.code:
          expr = parseBracket();
        case '['.code:
          expr = LexArray(parseArray());
        case "'".code, '"'.code:
          expr = LexString(parseString());

        case _ if (variableNameStart.contains(lastChar)):
          switch(getVariableName(lastChar)) {
            case 'true':
              expr = LexBool(true);
            case 'false':
              expr = LexBool(false);
            case 'null':
              expr = LexNull;
            case str:
              var args = parseCallArgs();
              switch(args.length > 0 ? args[0] : LexNull) {
                case LexAssignment(name, body):
                  throw 'expected call arguments but got an assignment instead';
                case _:
                  expr = LexCall(str, args);
              }
          }

        case _:
          invalidChar();
      }

      var terminatorChar : Int = getNextNonWhitespaceChar();
      if( terminatorChar != ')'.code ) errorTerminators([')'.code], toChar(terminatorChar));
      return expr;
    }

    throw 'expected \')\' but reached EOF';
  }

  // Parse an array of expressions between square brackets
  function parseArray() : Array<LexExpr> {
    var expressions : Array<LexExpr> = [];

    lastChar = nextChar();
    if( getNextNonWhitespaceChar() == ']'.code ) return expressions;
    pos--;

    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
          continue;
          // loop
        case '/'.code:
          stripComment();
        case _ if (numberStart.contains(lastChar)):
          expressions.push( LexNumber(parseNumberValue(lastChar)) );
        case '{'.code:
          expressions.push( LexObject(parseObject()));
          lastChar = nextChar();
        case '\\'.code:
          expressions.push( parseLambda() );
          lastChar = nextChar();
        case '('.code:
          expressions.push( parseBracket() );
          lastChar = nextChar();
        case '['.code:
          expressions.push( LexArray(parseArray()) );
          lastChar = nextChar();
        case "'".code, '"'.code:
          expressions.push(LexString(parseString()));
          lastChar = nextChar();

        case _ if (variableNameStart.contains(lastChar)):
          expressions.push(parseArrayVariableName(lastChar));
      }

      switch(getNextNonWhitespaceChar()) {
        case ','.code:
          // do nothing
        case ']'.code:
          return expressions;
        case char:
          errorTerminators([','.code, ']'.code], toChar(char));
      }
    }
    throw 'expected array expression but reached EOF';
  }

  // Parse the value from a name
  // in the array context
  function parseArrayVariableName(startChar : Int) : LexExpr {
    switch(getVariableName(startChar)) {
      case 'true':
        return LexBool(true);
      case 'false':
        return LexBool(false);
      case 'null':
        return LexNull;
      case str:
        var args = parseCallArgs();

        switch(args.length > 0 ? args[0] : LexNull) {
          case LexAssignment(name, body):
            throw 'expected call arguments but got an assignment instead';
          case _:
            return LexCall(str, args);
        }
    }
    throw 'invalid array expression';
  }

  // Parse the names of the arguments for a function
  function parseFunctionArgs() : Array<String> {
    var args : Array<String> = [];

    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code:
          continue;
        case _ if(variableNameStart.contains(lastChar)):
          args.push(getVariableName(lastChar));
        case _:
          return args;
      }
      switch(lastChar) {
        case ' '.code, '\t'.code:
        case _:
          return args;
      }
    }
    throw 'expected function but encountered EOF';
  }

  // Parse the expressions for a function to execute
  function parseFunctionBody() : Array<LexExpr> {
    var body : Array<LexExpr> = [];

    var nonWhitespaceChar : Int = getNextNonWhitespaceChar();
    if(nonWhitespaceChar != '{'.code) throw 'expected \'{\' but got \'${toChar(nonWhitespaceChar)}\'';

    nonWhitespaceChar = getNextNonWhitespaceChar();
    if(nonWhitespaceChar == '}'.code) return body;

    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case '}'.code:
          return body;
        case '/'.code:
          stripComment();
          continue;
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
          continue;
          // loop
        case _ if (numberStart.contains(lastChar)):
          body.push( LexNumber(parseNumberValue(lastChar)) );
        case '{'.code:
          body.push( LexObject(parseObject()) );
        case '\\'.code:
          body.push( parseLambda() );
          lastChar = nextChar();
        case '('.code:
          body.push( parseBracket() );
          lastChar = nextChar();
        case '['.code:
          body.push( LexArray(parseArray()) );
          lastChar = nextChar();
        case "'".code, '"'.code:
          body.push( LexString(parseString()) );
          lastChar = nextChar();

        case _ if (variableNameStart.contains(lastChar)):
          body.push(parseFunctionVarName(lastChar));
        case _:
          invalidChar();
      }

      nonWhitespaceChar = getNextNonWhitespaceCharExcludingNewline();
      if(nonWhitespaceChar == '}'.code) return body;
      if(nonWhitespaceChar != '\n'.code) throw 'expected newline before function expression';
    }

    throw 'expected function body expression but encountered EOF';
  }

  // Parse an expression from a name
  // in a function context  
  function parseFunctionVarName(startChar : Int) : LexExpr {
    switch(getVariableName(startChar)) {
      case 'if':
        var ifExpr : LexExpr = parseIfStatement();
        lastChar = nextChar();
        return ifExpr;
      case 'while':
        var whileExpr : LexExpr = parseWhileStatement();
        lastChar = nextChar();
        return whileExpr;
      case 'true':
        return LexBool(true);
      case 'false':
        return LexBool(false);
      case 'null':
        return LexNull;
      case 'let':
        return parseVariableCreation(ConstantVariable);
      case 'set':
        return parseVariableCreation(NonConstantVariable);
      case str:
        var args = parseCallArgs();
        switch(args.length > 0 ? args[0] : LexNull) {
          case LexAssignment(name, val):
            return LexAssignment(str, val);
          case _:
            return LexCall(str, args);
        }
    }

    throw 'Expected Function Body Expression';
  }

  // Parse an associative list of elements
  function parseObject() : Map<String, LexExpr> {
    var expressions : Map<String, LexExpr> = [];

    lastChar = nextChar();
    if(getNextNonWhitespaceChar() == '}'.code) return expressions;
    pos--;

    while( !StringTools.isEof(lastChar) ) {
      var objName : String = parseObjectVarName();
      if (expressions.exists(objName)) throw 'cannot have duplicate names in object';

      var nonWhitespaceChar : Int = getNextNonWhitespaceChar();
      if( nonWhitespaceChar != ':'.code) errorTerminators([':'.code], toChar(nonWhitespaceChar));

      while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
        switch(lastChar) {
          case '/'.code:
            stripComment();
            continue;
          case ' '.code, '\t'.code, '\r'.code, '\n'.code:
            continue;
            // loop
          case _ if (numberStart.contains(lastChar)):
            expressions[objName] = LexNumber(parseNumberValue(lastChar));
          case '{'.code:
            expressions[objName] = LexObject(parseObject());
            lastChar = nextChar();
          case '\\'.code:
            expressions[objName] = parseLambda();

          case '('.code:
            expressions[objName] = parseBracket();
            lastChar = nextChar();
          case '['.code:
            expressions[objName] = LexArray(parseArray());
            lastChar = nextChar();
          case "'".code, '"'.code:
            expressions[objName] = LexString(parseString());
            lastChar = nextChar();

          case _ if (variableNameStart.contains(lastChar)):
            expressions[objName] = parseArrayVariableName(lastChar);
          case _:
            throw 'expected expression but got \'${toChar(lastChar)}\'';
        }

        break;
      }

      nonWhitespaceChar = getNextNonWhitespaceChar();
      if(nonWhitespaceChar == '}'.code) return expressions;
      if(nonWhitespaceChar != ','.code) pos--;
    }

    throw 'expected object expression but reached EOF';
  }

  // Parse the key for an object
  function parseObjectVarName() : String {
    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
          // loop
        case _ if(variableNameStart.contains(lastChar)):
          var objName : String = getVariableName(lastChar);
          pos--;
          return objName;
          break;
        case _:
          throw 'expected variable name for object but got \'${toChar(lastChar)}\'';
      }
    }
    return 'expected object name but reached EOF';
  }

  // Parse an if-else control statement 
  function parseIfStatement() : LexExpr {
    var condition = parseVariableAssignmentExpr();
    lastChar = nextChar();

    var ifBody = parseFunctionBody();
    lastChar = nextChar();

    var elseBody = parseFunctionBody();

    return LexIf(condition, ifBody, elseBody);
  }

  // Parse a while control statement
  function parseWhileStatement() : LexExpr {
    var condition = parseVariableAssignmentExpr();
    lastChar = nextChar();
    var body = parseFunctionBody();
    return LexWhile(condition, body);
  }

  // Parse an lambda data type
  function parseLambda() : LexExpr {
    switch((lastChar = nextChar())) {
      case '('.code:
      case _:
        throw 'expected \'\\(\' for lambda expressions but got \'\\${toChar(lastChar)}';
    }
    var args = parseLambdaArgs();
    lastChar = nextChar();

    return LexLambda(args, parseFunctionBody());
  }

  // Parse the names of the lambda's arguments
  // This differs from parseFunctionArgs because
  // Lambda arguments are ended with \)
  function parseLambdaArgs() : Array<String> {
    var args :Array<String> = [];

    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
          continue;
        case _ if(variableNameStart.contains(lastChar)):
          args.push(getVariableName(lastChar));
        case '\\'.code:
          break;
        case _:
          throw 'expected \'\\)\' to end lambda arguments but got \'${toChar(lastChar)}\' instead';
      }

      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
        case '\\'.code:
          break;
        case _:
          throw 'expected \'\\)\' to end lambda arguments but got \'${toChar(lastChar)}\' instead';
      }
    }
    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch( lastChar ) {
        case ')'.code:
          return args;
        case _:
          throw 'expected \'\\)\' to end lambda arguments';
      }
    }

    throw 'expected lambda arguments but reached EOF';
  }

  // Return the number from the string using
  // a starting character
  function parseNumberValue(startChar:Int):Float {
    var numString = toChar(startChar);

    final numberValues : Array<Int> = [
      for(char in '0'.code...('9'.code + 1)) char
    ].concat([
        '.'.code
    ]);

    while(true) {
      switch((lastChar = nextChar())) {
        case '/'.code:
          stripComment();
        case _ if ( numberValues.contains(lastChar) ):
          numString += toChar(lastChar);
        default:
          switch(Std.parseFloat(numString)) {
            case num if ( Math.isNaN(num) ):
              throw 'Expected Number instead got \'$numString\'';
            case num:
              return num;
          }
      }
    }

    return 0;
  }

  // Return the name of a variable
  function getVariableName(startChar:Int):String {
    final variableNameMatch : Array<Int> = [
      for(char in 'a'.code...('z'.code + 1)) char
    ].concat([
      for(char in 'A'.code...('Z'.code + 1)) char
    ]).concat([
      for(char in '0'.code...('9'.code + 1)) char
    ]).concat([
      '_'.code
    ]);
    var name : String = toChar(startChar);
    while(true) {
      switch((lastChar = nextChar())) {
        case _ if(variableNameMatch.contains(lastChar)):
          name += toChar(lastChar);
        default:
          return name;
      }
    }
    return name;
  }

  // Parse the value between two double or single quotes
  // with escaping characters transformed
  function parseString() : String {
    var string = '';
    final stringId = lastChar;

    while( !StringTools.isEof( (lastChar = nextChar()) )) {
      switch(lastChar) {
        case '\\'.code:
          string += toChar(parseEscape());
        case _ if(lastChar == stringId):
          return string;
        case _:
          string += toChar(lastChar);
      }
    }
    return null;
  }

  //===============================================================---
  //  Functions that help create values for the lexer
  //  but are not used for creating the expression
  //===============================================================---

  // Convert backspaced characters into the correct
  // Value
  inline function parseEscape() : Int {
    switch( (lastChar = nextChar()) ) {
      case 'a'.code:
        return 0x07;
      case 'b'.code:
        return 0x08;
      case 'e'.code:
        return 0x1B;
      case 'f'.code:
        return 0x0C;
      case 'n'.code:
        return '\n'.code;
      case 'r'.code:
        return '\r'.code;
      case 't'.code:
        return '\t'.code;
      case 'v'.code:
        return 0x0B;
      case 'x'.code:
        return Std.parseInt('0x${ toChar(nextChar()) }${ toChar( (lastChar = nextChar()) ) }');
      case _:
        return lastChar;
    }
  }

  // Strip the comment depending on the type of comment
  // either '//'
  // or '/* */'
  function stripComment() : Void {
    switch( (lastChar = nextChar()) ) {
      case '/'.code:
        stripLineComment();
      case '*'.code:
        stripMultilineComment();
      case _:
        throw 'expected \'/\' or \'*\' for comment';
    }
  }

  //===============================================================---
  //  Functions that edit the internal string
  //  or modify the position
  //===============================================================---

  // Remove all the characters in the line
  function stripLineComment() : Void {
    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case '\n'.code:
          return;
      }
    }
  }

  // Remove all the characters between '/*' and '*/' including new lines
  function stripMultilineComment() : Void {
    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case '*'.code:
          switch((lastChar = nextChar())) {
            case '/'.code:
              return;
          }
      }
    }

    throw 'expected \'*/\' to end multi-line comment but encountered EOF';
  }

  // Helper function to get the next character in the file that isn't
  // a space, tab, carriage return, or newline
  function getNextNonWhitespaceChar() : Int {
    var char : Int = getNextNonWhitespaceCharExcludingNewline();
    while(char == '\n'.code) {
      lastChar = nextChar();
      char = getNextNonWhitespaceCharExcludingNewline();
    }
    return char;
  }

  // Helper function to get the next character in the file that isn't
  // a space, tab, or carriage return
  function getNextNonWhitespaceCharExcludingNewline() : Int {
    do {
      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code:
          // loop
        case _:
          return lastChar;
      }
    } while( !StringTools.isEof( (lastChar = nextChar()) ) );
    throw 'Encountered EOF';
  }

  // Helper function for erroring when expecting a specific character(s)
  inline function errorTerminators(terminators : Array<Int>, erroredOn : String) : Void {
    if(terminators.length == 0) throw 'expected more than 0 terminators';
    if(terminators.length == 1) {
      throw 'expected \'${toChar(terminators[0])}\' but got \'${erroredOn}\'';
    }
    throw 'expected one of \'${terminators}\' but got \'${erroredOn}\'';
  }

  // Helper function for turning character codes into a string
  inline function toChar(code:Int) : String {
    return String.fromCharCode(code);
  }

  // Get the next character in a string and increment the position in the string
  inline function nextChar():Int {
    return StringTools.fastCodeAt(str, pos++);
  }

  // Helper function for throwing an error when receiving an invalid character
  inline function invalidChar() : Void {
    pos--;
    throw 'invalid char \'${ toChar(StringTools.fastCodeAt(str, pos)) }\' at position $pos';
  }
}
