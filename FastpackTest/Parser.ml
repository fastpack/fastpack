let test_path = Test.get_test_path "parse"

let parse filename =
  let f source =
    match FastpackUtil.Parser2.parse ~location_str:filename source with
    | Ok _ -> "\nOK\n"
    | Error err -> "\n" ^ FastpackUtil.Run.formatError err ^ "\n"
  in
  Test.test f filename


let%expect_test "parse/valid.js" =
  parse "parse/valid.js";
  [%expect_exact {|
OK
|}]

let%expect_test "parse/invalid-small.js" =
  parse "parse/invalid-small.js";
  [%expect_exact {|
CONTEXT:
  Parsing parse/invalid-small.js

Parse Errors:
   1| for(i = 1;);
                ^ Unexpected token )
   1| for(i = 1;);
                 ^ Unexpected token ;
   2| class(){}
      ^ Unexpected token class
   2| class(){}
             ^ Unexpected token {
   2| class(){}
              ^ Unexpected token }
   3| 
      ^ Unexpected end of input
|}]

let%expect_test "parse/invalid-small.js" =
  parse "parse/invalid-small.js";
  [%expect_exact {|
CONTEXT:
  Parsing parse/invalid-small.js

Parse Errors:
   1| for(i = 1;);
                ^ Unexpected token )
   1| for(i = 1;);
                 ^ Unexpected token ;
   2| class(){}
      ^ Unexpected token class
   2| class(){}
             ^ Unexpected token {
   2| class(){}
              ^ Unexpected token }
   3| 
      ^ Unexpected end of input
|}]

let%expect_test "parse/test.css" =
  parse "parse/test.css";
  [%expect_exact {|
CONTEXT:
  Parsing parse/test.css

Parse Error

SUGGESTION:
Looks like you are trying to parse the CSS file. Try to preprocess them like this:
  --preprocess='\.css$:style-loader!css-loader'
|}]
