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
  LexIf(condition : LexExpr, if_body : Array<LexExpr>, else_body : Array<LexExpr>);
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
  public static inline function parse(file_str:String) : Array<LexExpr> {
    return new Lexer(file_str).doParse();
  }

  // Variables for file iteration
  var str:String;
  var pos:Int;
  var lastChar:Int;

  // Array of whitespace characters
  final whitespace : Array<Int> = [' '.code, '\t'.code, '\n'.code, '\r'.code];
  
  // Array of characters that variable names can start with
  final variableNameStart :Array<Int> = [
    for (i in 'a'.code...('z'.code + 1)) i
  ].concat([
      for (i in 'A'.code...('Z'.code + 1)) i   
  ]).concat([
    '_'.code
  ]);

  // Array of characters that number can start with
  final numberStart : Array<Int> = [
    for(i in '0'.code...('9'.code + 1)) i
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
        case c if(whitespace.contains(c)):
          // loop
        case '/'.code:
          stripComment();
        case c if( variableNameStart.contains(c) ):

          switch(getVariableName(c)) {
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
        case c:
          throw 'invalid top level expression \'${ toChar(c) }\' at pos: $pos';
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
        case c if(variableNameStart.contains(c)): // If it is a valid character for a variable

          final var_name = getVariableName(c); // Get the function name for the extern
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
          
          return LexExternJS(var_name, args, profile);
        case c:
          throw 'expected extern expression, instead got\'${toChar(c)}\''; 
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
        case c if( variableNameStart.contains(c) ): // do we have a valid variable name starting character?

          return LexAssignment(getVariableName(c), parseVariableCreationBody());
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
        case c:
          throw 'expected \'=\' after variable name, got \'${ toChar(c) }';
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
        case n if (numberStart.contains(n)):
          return LexNumber(parseNumberValue(n));
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

        case c if (variableNameStart.contains(c)):
          switch(getVariableName(c)) {
            case 'true':
              return LexBool(true);
            case 'false':
              return LexBool(false);
            case 'null':
              return LexNull;
            case str:
              var args = parseCallArgs();
              if(args.length == 1) {
                switch(args[0]) {
                  case LexAssignment(name, body):
                    throw 'expected call arguments but got an assignment instead';
                  default:
                }
              }
              return LexCall(str, args);
          }

        case c:
          throw 'expected expression but got \'${toChar(c)}\'';
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
        case n if (numberStart.contains(n)):
          args.push( LexNumber(parseNumberValue(n)) );
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

        case c if (variableNameStart.contains(c)):
          switch(getVariableName(c)) {
            case 'true':
              args.push( LexBool(true) );
            case 'false':
              args.push( LexBool(false) );
            case 'null':
              args.push( LexNull );
            case str:
              args.push( LexCall(str, []) );
          }

        case c:
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
        case n if (numberStart.contains(n)):
          expr = LexNumber(parseNumberValue(n));
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

        case c if (variableNameStart.contains(c)):
          switch(getVariableName(c)) {
            case 'true':
              expr = LexBool(true);
            case 'false':
              expr = LexBool(false);
            case 'null':
              expr = LexNull;
            case str:
              var args = parseCallArgs();
              if(args.length == 1) {
                switch(args[0]) {
                  case LexAssignment(name, body):
                    throw 'expected call arguments but got an assignment instead';
                  case c:
                }
              }
              expr = LexCall(str, args);
          }

        case c:
          invalidChar();
      }

      do {
        switch(lastChar) {
          case ' '.code, '\t'.code, '\r'.code, '\n'.code:
            // loop
          case ')'.code:
            return expr;
          case c:
            throw 'expected \')\' but got ${toChar(c)}';
        }
      } while( !StringTools.isEof( (lastChar = nextChar()) ) );
    }

    throw 'expected \')\' but reached EOF';
  }

  // Parse an array of expressions between square brackets
  function parseArray() : Array<LexExpr> {
    var expressions : Array<LexExpr> = [];
    
    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
          // loop
        case ']'.code:
          return expressions;
        default:
          pos--;
          break;
      }
    }

    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
          continue;
          // loop
        case '/'.code:
          stripComment();
        case n if (numberStart.contains(n)):
          expressions.push( LexNumber(parseNumberValue(n)) );
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

        case c if (variableNameStart.contains(c)):
          switch(getVariableName(c)) {
            case 'true':
              expressions.push( LexBool(true) );
            case 'false':
              expressions.push( LexBool(false) );
            case 'null':
              expressions.push( LexNull );
            case str:
              var args = parseCallArgs();
              if(args.length == 1) {
                switch(args[0]) {
                  case LexAssignment(name, body):
                    throw 'expected call arguments but got an assignment instead';
                  case c:
                }
              }
              expressions.push( LexCall(str, args) );
          }
      }

      do {
        switch(lastChar) {
          case ' '.code, '\t'.code, '\r'.code, '\n'.code:
            continue;
            // loop
          case ','.code:
            break;
          case ']'.code:
            return expressions;
          case c:
            throw 'expected \',\' or \']\', instead got \'${toChar(c)}\'';
            pos--;
            break;
        }
      } while( !StringTools.isEof( (lastChar = nextChar()) ) );
    }
   throw 'expected array expression but reached EOF'; 
  }

  // Parse the names of the arguments for a function
  function parseFunctionArgs() : Array<String> {
    var args : Array<String> = [];

    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code:
          continue;
        case c if(variableNameStart.contains(c)):
          args.push(getVariableName(c));
        case c:
          return args;
      }
      switch(lastChar) {
        case ' '.code, '\t'.code:
        case c:
          return args;
      }
    }
    throw 'expected function but encountered EOF';
  }

  // Parse the expressions for a function to execute
  function parseFunctionBody() : Array<LexExpr> {
    var body : Array<LexExpr> = [];
    do {
      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
        case '{'.code:
          break;
        case c:
          throw 'expected \'{\' but got \'${toChar(c)}\'';
      }
    } while( !StringTools.isEof( (lastChar = nextChar()) ) );

    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
          // loop
        case '}'.code:
          return body;
        case c:
          pos--;
          break;
      }
    }

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
        case n if (numberStart.contains(n)):
          body.push( LexNumber(parseNumberValue(n)) );
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

        case c if (variableNameStart.contains(c)):
          switch(getVariableName(c)) {
            case 'if':
              body.push(parseIfStatement());
              lastChar = nextChar();
            case 'while':
              body.push(parseWhileStatement());
              lastChar = nextChar();
            case 'true':
              body.push( LexBool(true) );
            case 'false':
              body.push( LexBool(false) );
            case 'null':
              body.push( LexNull );
            case 'let':
              body.push( parseVariableCreation(ConstantVariable) );
              continue;
            case 'set':
              body.push( parseVariableCreation(NonConstantVariable) );
              continue;
            case str:
              var args = parseCallArgs();
              if(args.length == 1) {
                switch(args[0]) {
                  case LexAssignment(name, b):
                    body.push( LexAssignment(str, b) );
                  case c:
                    body.push(LexCall(str, args));
                }
              } else {
                body.push(LexCall(str, args));
              }
          }

        case c:
          invalidChar();
      }

      do {
        switch(lastChar) {
          case ' '.code, '\t'.code, '\r'.code:
            // loop
          case '\n'.code:
            break;
          case '}'.code:
            return body;
          case c:
            throw 'expected newline before function expression';
        } 
      } while( !StringTools.isEof( (lastChar = nextChar()) ) );
    }

    throw 'expected function body expression but encountered EOF';
  }

  // Parse an associative list of elements
  function parseObject() : Map<String, LexExpr> {
    var expressions : Map<String, LexExpr> = [];

    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
          // loop
        case '}'.code:
          return expressions;
        case c:
          pos--;
          break;
      }
    }

    while( !StringTools.isEof(lastChar) ) {

      var obj_name = '';
       
      while( !StringTools.isEof( (lastChar = nextChar()) ) ) {

        switch(lastChar) {
          case ' '.code, '\t'.code, '\r'.code, '\n'.code:
            // loop
          case c if(variableNameStart.contains(c)):
            obj_name = getVariableName(c);
            if (expressions.exists(obj_name)) {
              throw 'cannot have duplicate names in object';
            }
            pos--;
            break;
          case c:
            throw 'expected variable name for object but got \'${toChar(c)}\'';
        }
      }

      while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
        switch(lastChar) {
          case ' '.code, '\t'.code, '\r'.code, '\n'.code:
            // loop
          case ':'.code:
            break;
          case c:
            throw 'expected \':\' but got \'${toChar(c)}\'';
        }
      }

      while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
        switch(lastChar) {
          case '/'.code:
            stripComment();
            continue;
          case ' '.code, '\t'.code, '\r'.code, '\n'.code:
            continue;
            // loop
          case n if (numberStart.contains(n)):
            expressions[obj_name] = LexNumber(parseNumberValue(n));
          case '{'.code:
            expressions[obj_name] = LexObject(parseObject());
            lastChar = nextChar();
          case '\\'.code:
            expressions[obj_name] = parseLambda();

          case '('.code:
            expressions[obj_name] = parseBracket();
            lastChar = nextChar();
          case '['.code:
            expressions[obj_name] = LexArray(parseArray());
            lastChar = nextChar();
          case "'".code, '"'.code:
            expressions[obj_name] = LexString(parseString());
            lastChar = nextChar();

          case c if (variableNameStart.contains(c)):
            switch(getVariableName(c)) {
              case 'true':
                expressions[obj_name] = LexBool(true);
              case 'false':
                expressions[obj_name] = LexBool(false);
              case 'null':
                expressions[obj_name] = LexNull;
              case str:
                expressions[obj_name] = LexCall(str, []);
            }

          case c:
            throw 'expected expression but got \'${toChar(c)}\'';
        }

        break;

      }

      do {
        switch(lastChar) {
          case ' '.code, '\t'.code, '\r'.code, '\n'.code:
            // loop
          case ','.code:
            break;
          case '}'.code:
            return expressions;
          default:
            pos--;
            break;
        }
      } while( !StringTools.isEof( (lastChar = nextChar()) ) );

    }

    throw 'expected object expression but reached EOF';
  }

  // Parse an if-else control statement 
  function parseIfStatement() : LexExpr {
    var condition = parseVariableAssignmentExpr();
    lastChar = nextChar();

    var if_body = parseFunctionBody();
    lastChar = nextChar();

    var else_body = parseFunctionBody();

    return LexIf(condition, if_body, else_body);
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
      case c:
        throw 'expected \'\\(\' for lambda expressions but got \'\\${toChar(c)}';
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
        case c if(variableNameStart.contains(c)):
          args.push(getVariableName(c));
        case '\\'.code:
          break;
        case c:
          throw 'expected \'\\)\' to end lambda arguments but got \'${toChar(c)}\' instead';
      }

      switch(lastChar) {
        case ' '.code, '\t'.code, '\r'.code, '\n'.code:
        case '\\'.code:
          break;
        case c:
          throw 'expected \'\\)\' to end lambda arguments but got \'${toChar(c)}\' instead';
      }
    }
    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch( lastChar ) {
        case ')'.code:
          return args;
        case c:
          throw 'expected \'\\)\' to end lambda arguments';
      }
    }

    throw 'expected lambda arguments but reached EOF';
  }

  // Return the number from the string using
  // a starting character
  function parseNumberValue(start_char:Int):Float {
    var num_string = toChar(start_char);

    final numberValues : Array<Int> = [
      for(i in '0'.code...('9'.code + 1)) i
    ].concat([
        '.'.code
    ]);

    while(true) {
      var char = nextChar();
      lastChar = char;
      switch(char) {
        case '/'.code:
          stripComment();
        case n if ( numberValues.contains(n) ):
          num_string += toChar(n);
        default:
          switch(Std.parseFloat(num_string)) {
            case num if ( Math.isNaN(num) ):
              throw 'Expected Number instead got \'$num_string\'';
            case num:
              return num;
          } 
      }
    }

    return 0;
  }

  // Return the name of a variable
  function getVariableName(start_char:Int):String {
    final variableNameMatch : Array<Int> = [
      for(i in 'a'.code...('z'.code + 1)) i
    ].concat([
      for(i in 'A'.code...('Z'.code + 1)) i
    ]).concat([
      for(i in '0'.code...('9'.code + 1)) i
    ]).concat([
      '_'.code
    ]);
    var name : String = toChar(start_char);
    while(true) {
      var char = nextChar();
      lastChar = char;
      switch(char) {
        case _ if(variableNameMatch.contains(char)):
          name += toChar(char);
        default:
          return name;

      }
    }
    return name;
  }

  // Parse the value between two double or single quotes
  // with escaping characters transformed
  function parseString() : String {
    var string = "";
    final stringId = lastChar;

    while( !StringTools.isEof( (lastChar = nextChar()) )) {
      switch(lastChar) {
        case '\\'.code:
          string += String.fromCharCode(parseEscape()); 
        case c if(c == stringId):
          return string;
        case c:
          string += String.fromCharCode(c);
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
      case c:
        return c;
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
      case c:
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
