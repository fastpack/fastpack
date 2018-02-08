open Util

let%expect_test "error-parse" =
  run_with_filename pack_regular_prod "error-parse/index.js";
  [%expect {|

Working Directory: /.../test/error-parse
Entry Point: index.js
Mode: production
Call Stack:
	'./a' from file: index.js
Processing File: a.js

Parse Error
File: a.js
	(1:15) - (1:16): Unexpected token ;
  |}]
