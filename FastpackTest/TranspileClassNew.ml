let transpileClassOnly source =
  FastpackTranspiler.transpile_source [
    FastpackTranspiler.ClassNew.transpile;
  ] source |> fst |> print_string

let%expect_test "empty class" =
  transpileClassOnly {|
  class C {}
  |};
  [%expect_exact {||}]
