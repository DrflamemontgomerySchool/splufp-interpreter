package parser;

enum FuncType {
  ConstantVariable;
  NonConstantVariable;
  Function;
}

enum LexExpr {
  LexNull;
  LexBool(val:Bool);
  LexNumber(val:Float);
  LexString(val:String);
  LexArray(val:Array<LexExpr>);
  LexObject(val:Map<String, LexExpr>);
  LexFunction(type:FuncType, name:String, args:Array<String>, body:Array<LexExpr>); // also variable
  LexCall(name:String, args:Array<String>);
  LexAssignment(name:String, val:LexExpr);
}

class Lexer {
  
  public static inline function parse(str:String) : Array<LexExpr> {
    return new Lexer(str).doParse();
  }

  var str:String;
  var pos:Int;
  var lastChar:Int;
  final whitespace : Array<Int> = [' '.code, '\t'.code, '\n'.code, '\r'.code];
  final variableNameStart :Array<Int> = [
    for (i in 'a'.code...'z'.code) i
  ].concat([
      for (i in 'A'.code...'Z'.code) i   
  ]).concat([
    '_'.code
  ]);

  final numberStart : Array<Int> = [
    for(i in '0'.code...'9'.code) i
  ].concat([
      '-'.code, '.'.code
  ]);


  function new(str:String) {
    this.str = str;
    this.pos = 0;
  }
  
  function doParse():Array<LexExpr> {

    var data : Array<LexExpr> = [];

    while( true ) {
      switch(parseTopLevel()) {
        case null:
          return data;
        case expr:
          data.push( expr );
      }
    }
    return data;
  }

  function parseTopLevel() : Null<LexExpr> {


    var c : Int;
    while( !StringTools.isEof( (c = nextChar()) ) ) {
      lastChar = c; 
      switch(c) {
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
              throw 'external javascript functions are not implemented';
            case 'macro':
              throw 'macros are not implemented';
            case str:
              throw 'functions are not implemented';
          }
        case c:
          throw 'invalid top level expression \'${ toChar(c) }\' at pos: $pos';
      }
    }
    return null;
  }

  function parseVariableCreation(type : FuncType) : LexExpr {
    switch(lastChar) {
      case ' '.code, '\t'.code:
      case str if( type == ConstantVariable ):
        'expected whitespace after \'let\', received \'$str\' instead';
      case str if( type == NonConstantVariable ):
        'expected whitespace after \'set\', received \'$str\' instead';
      case str:
        'variable type invalid';
    }

    switch(parseVariableAssignment() ) {
      case LexAssignment(name, val):
        return LexFunction(type, name, [], [val]);
      default:
        throw 'expected variable assignment';
    }
  }

  function parseVariableAssignment() : LexExpr {
    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case ' '.code, '\t'.code:
          // loop
        case '/'.code:
          stripComment();
        case c if( variableNameStart.contains(c) ):
          return LexAssignment(getVariableName(c), parseVariableCreationBody());

          // variable Name
        case str:
          throw 'expected variable name, received \'$str\' instead';
      }
    }
    
    throw 'expected variable expression but reached EOF';
  }

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
          throw 'objects are not implemented';
        case '\\'.code:
          throw 'lambdas are not implemented';
        case '('.code:
          throw 'bracket expressions are not implemented';
        case '['.code:
          return LexArray(parseArrayValue());
          //throw 'arrays are not implemented';
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
              return LexCall(str, []);
              //throw 'variable references not implemented';
          }

        case c:
          invalidChar();
      }
    }
    
    throw 'expected variable expression but reached EOF';
  }
  
  function parseArrayValue() : Array<LexExpr> {
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
          // loop
        case '/'.code:
          stripComment();
        case n if (numberStart.contains(n)):
          expressions.push( LexNumber(parseNumberValue(n)) );
        case '{'.code:
          throw 'objects are not implemented';
        case '\\'.code:
          throw 'lambdas are not implemented';
        case '('.code:
          throw 'bracket expressions are not implemented';
        case '['.code:
          expressions.push( LexArray(parseArrayValue()) );
          lastChar = nextChar();
          //throw 'arrays are not implemented';
        case "'".code, '"'.code:
          expressions.push(LexString(parseString()));

        case c if (variableNameStart.contains(c)):
          switch(getVariableName(c)) {
            case 'true':
              expressions.push( LexBool(true) );
            case 'false':
              expressions.push( LexBool(false) );
            case 'null':
              expressions.push( LexNull );
            case str:
              expressions.push( LexCall(str, []) );
              //throw 'variable references not implemented';
          }
      }

      do {
        switch(lastChar) {
          case ' '.code, '\t'.code, '\r'.code, '\n'.code:
            // loop
          case ','.code:
            break;
          case ']'.code:
            return expressions;
          default:
            pos--;
            break;
        }
      } while( !StringTools.isEof( (lastChar = nextChar()) ) );

    }
   throw 'expected array expression but reached EOF'; 
  }

  function parseNumberValue(start_char:Int):Float {
    var num_string = toChar(start_char);

    final numberValues : Array<Int> = [
      for(i in '0'.code...'9'.code) i
    ].concat([
        '.'.code
    ]);

    while(true) {
      var c = nextChar();
      lastChar = c;
      switch(c) {
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

  function getVariableName(start_char:Int):String {
    final variableNameMatch : Array<Int> = [
      for(i in 'a'.code...'z'.code) i
    ].concat([
      for(i in 'A'.code...'Z'.code) i
    ]).concat([
      for(i in '0'.code...'0'.code) i
    ]).concat([
      '_'.code
    ]);
    var name : String = toChar(start_char);
    while(true) {
      var c = nextChar();
      lastChar = c;
      switch(c) {
        case _ if(variableNameMatch.contains(c)):
          name += toChar(c);
        default:
          return name;

      }
    }
    return name;
  }

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

  inline function parseEscape() : Int {
    switch( (lastChar = nextChar()) ) {
      case 'a'.code:
        return 0x07;
      case 'b'.code:
        return 0x08;
      case 'e'.code:
        return 0x1b;
      case 'f'.code:
        return 0x0c; 
      case 'n'.code:
        return '\n'.code;
      case 'r'.code:
        return '\r'.code;
      case 't'.code:
        return '\t'.code;
      case 'v'.code:
        return 0x0b;
      case 'x'.code:
        return Std.parseInt('0x${ toChar(nextChar()) }${ toChar( (lastChar = nextChar()) ) }');
      case c:
        return c;
    }
  }

  function stripLineComment() : Void {
    while( !StringTools.isEof( (lastChar = nextChar()) ) ) {
      switch(lastChar) {
        case '\n'.code:
          return;
      }
    }
  }

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

  inline function toChar(code:Int) : String {
    return String.fromCharCode(code);
  }

  inline function nextChar():Int {
    return StringTools.fastCodeAt(str, pos++);
  }

  function invalidChar() {
    pos--;
    throw 'invalid char \'${ toChar(StringTools.fastCodeAt(str, pos)) }\' at position $pos';
  }
}
