open Util

let%expect_test "error-cannot-find-exported-name" =
  run_with_filename pack_flat_prod "error-cannot-find-exported-name/index.js";
  [%expect {|

Working Directory: /.../test/error-cannot-find-exported-name
Entry Point: index.js
Mode: production
Call Stack: (empty)
Processing File: index.js

Cannot find exported name 'b' in module 'a.js'
  |}]
