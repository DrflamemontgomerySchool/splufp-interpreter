package parser;

enum LexExpr {
  LexNull;
  LexBool(val:Bool);
  LexNumber(val:Float);
  LexArray(val:Array<LexExpr>);
  LexObject(val:Map<String, LexExpr>);
  LexFunction(isConst:Bool, name:String, args:Array<String>, body:Array<LexExpr>); // also variable
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

    final numberStart : Array<Int> = [
      for(i in '0'.code...'9'.code) i
    ].concat([
        '-'.code, '.'.code
    ]);

    var c : Int;
    while( !StringTools.isEof( (c = nextChar()) ) ) {
      lastChar = c; 
      switch(c) {
        case c if(whitespace.contains(c)):
          // loop
        case c if( variableNameStart.contains(c) ):

          switch(getVariableName(c)) {
            case 'let':
              trace('constant');
              return parseVariableCreation(true);
            case 'set':
              trace('non-constant');
              return parseVariableCreation(false);
            case 'externjs':
              throw 'external javascript functions are not implemented';
            case 'macro':
              throw 'macros are not implemented';
            case str:
              throw 'functions are not implemented';
          }
        case c:
          throw 'invalid top level expression \'$c\' at pos: $pos';
      }
    }
    return null;
  }

  function parseVariableCreation(isConstant : Bool) : LexExpr {
    return LexFunction(isConstant, "", [], []);
  }

  function getNumberValue(start_char:Int):Float {
    var num_string = String.fromCharCode(start_char);

    final numberValues : Array<Int> = [
      for(i in '0'.code...'9'.code) i
    ].concat([
        '.'.code
    ]);

    while(true) {
      var c = nextChar();
      lastChar = c;
      switch(c) {
        case n if ( numberValues.contains(n) ):
          num_string += String.fromCharCode(n);
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
    var name : String = String.fromCharCode(start_char);
    while(true) {
      var c = nextChar();
      lastChar = c;
      switch(c) {
        case _ if(variableNameMatch.contains(c)):
          name += String.fromCharCode(c);
        default:
          return name;

      }
    }
    return name;
  }

  inline function nextChar():Int {
    return StringTools.fastCodeAt(str, pos++);
  }
}
