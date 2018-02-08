open Util

let%expect_test "error-dependency-cycle" =
  run_with_filename pack_flat_prod "error-dependency-cycle/index.js";
  [%expect {|

Working Directory: /.../test/error-dependency-cycle
Entry Point: index.js
Mode: production
Call Stack: (empty)
Processing File: index.js

Dependency cycle detected:
	a.js
	c.js
	b.js
	a.js
	index.js
  |}]
