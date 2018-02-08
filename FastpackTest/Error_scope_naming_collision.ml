open Util

let%expect_test "error-scope-naming-collision" =
  run_with_filename pack_flat_prod "error-scope-naming-collision/index.js";
  [%expect {|

Working Directory: /.../test/error-scope-naming-collision
Entry Point: index.js
Mode: production
Call Stack: (empty)
Processing File: index.js

Naming Collision: name 'a' at (3:4) - (3:5) is already defined at (1:4) - (1:5)
  |}]
