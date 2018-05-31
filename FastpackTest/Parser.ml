let test_path = Test.get_test_path "parse"

let parse filename =
  let f source =
    match FastpackUtil.Parser2.parse ~location_str:filename source with
    | Ok _ -> "\nParsed successfully\n"
    | Error err -> "\n" ^ FastpackUtil.Run.formatError err ^ "\n"
  in
  Test.test f filename


let%expect_test "parse/valid.js" =
  parse "parse/valid.js";
  [%expect_exact {|
Parsed successfully
|}]
