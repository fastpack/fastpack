open Util

let%expect_test "error-cannot-leave-package-dir" =
  run_with_filename pack_regular_prod "error-cannot-leave-package-dir/index.js";
  [%expect {|

Working Directory: /.../test/error-cannot-leave-package-dir
Entry Point: index.js
Mode: production
Call Stack:
	'../LeavePackageDir' from file: a.js	
'./a' from file: index.js
Processing File: a.js

/.../test/LeavePackageDir.js is out of the working directory
  |}]
