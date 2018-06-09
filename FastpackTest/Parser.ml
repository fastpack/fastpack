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
  Parsing parse/invalid-small.js
|}]
