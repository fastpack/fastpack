open Util

let%expect_test "error-cannot-resolve-modules" =
  run_with_filename pack_regular_prod "error-cannot-resolve-modules/index.js";
  [%expect {|

Working Directory: /.../test/error-cannot-resolve-modules
Entry Point: index.js
Mode: production
Call Stack: (empty)
Processing File: index.js

Cannot resolve modules:
	'./c' from file: index.js
	'./b' from file: index.js
	'./a' from file: index.js
  |}]
