{
open Lexing

type token =
  | UNDERSCORE
  | TYPE
  | KW_DEF
  | KW_INJ
  | KW_THM
  | RIGHTSQU
  | RIGHTPAR
  | RIGHTBRA
  | QID        of (string * string)
  | REQUIRE    of string
  | LONGARROW
  | LEFTSQU
  | LEFTPAR
  | LEFTBRA
  | ID         of string
  | FATARROW
  | EOF
  | DOT
  | DEF
  | COMMA
  | COLON
  | CCOLON
  | EQUAL
  | ARROW
  | EVAL
  | INFER
  | ASSERT
  | ASSERTNOT
  | PRINT
  | GDT
  | INT        of int
}

let space   = [' ' '\t' '\r']
let mident  = ['a'-'z' 'A'-'Z' '0'-'9' '_']+
let ident   = ['a'-'z' 'A'-'Z' '0'-'9' '_' '!' '?']['a'-'z' 'A'-'Z' '0'-'9' '_' '!' '?' '\'' ]*
let capital = ['A'-'Z']+

rule token = parse
  | space       { token lexbuf  }
  | '\n'        { new_line lexbuf ; token lexbuf }
  | "(;"        { comment lexbuf}
  | '.'         { DOT           }
  | ','         { COMMA         }
  | ':'         { COLON         }
  | "=="        { EQUAL         }
  | '['         { LEFTSQU       }
  | ']'         { RIGHTSQU      }
  | '{'         { LEFTBRA       }
  | '}'         { RIGHTBRA      }
  | '('         { LEFTPAR       }
  | ')'         { RIGHTPAR      }
  | "-->"       { LONGARROW     }
  | "->"        { ARROW         }
  | "=>"        { FATARROW      }
  | ":="        { DEF           }
  | "_"         { UNDERSCORE    }
  | "Type"      { TYPE          }
  | "def"       { KW_DEF        }
  | "inj"       { KW_INJ        }
  | "thm"       { KW_THM        }
  | "#REQUIRE" space+ (mident as md) { REQUIRE md }
  | "#EVAL"     { EVAL          }
  | "#INFER"    { INFER         }
  | "#ASSERT"   { ASSERT        }
  | "#ASSERTNOT"{ ASSERTNOT     }
  | "#PRINT"    { PRINT         }
  | "#GDT"      { GDT           }
  | mident as md '.' (ident as id) { QID (md, id) }
  | ident  as id { ID  id }
  | _   as c    { failwith (Printf.sprintf "Unexpected characters '%c'." c) }
  | eof         { EOF }

and comment = parse
  | ";)" { token lexbuf }
  | '\n' { new_line lexbuf ; comment lexbuf }
  | _    { comment lexbuf }
  | eof  { failwith "Unclosed comment." }
