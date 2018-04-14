
let%expect_test "expect" =
  print_endline "xxx\nyyy\nzzz";
  [%expect {|xx|}]
