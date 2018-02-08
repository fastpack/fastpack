open Util

let%expect_test "error-scope-previously-undefined-export" =
  run_with_filename pack_flat_prod "error-scope-previously-undefined-export/index.js";
  [%expect {|

Working Directory: /.../test/error-scope-previously-undefined-export
Entry Point: index.js
Mode: production
Call Stack: (empty)
Processing File: index.js

Cannot export previously undefined name 'a'
  |}]
