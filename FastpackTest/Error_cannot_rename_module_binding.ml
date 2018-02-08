open Util

let%expect_test "error-cannot-rename-module-binding" =
  run_with_filename pack_regular_prod "error-cannot-rename-module-binding/index.js";
  [%expect {|

Working Directory: /.../test/error-cannot-rename-module-binding
Entry Point: index.js
Mode: production
Call Stack: (empty)
Processing File: index.js


Cannot rename module binding:
(3:9) - (3:10): a
Import Request: './a' from file: index.js
Typically, it means that you are trying to use the name before importing it in
the code.
  |}]
