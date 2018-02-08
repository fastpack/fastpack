open Util

let%expect_test "error-pack-regular-esm" =
  run_with_filename pack_regular_esm "pack-target/index.js";
  (* Printf.printf "%s" @@ Unix.getcwd (); *)
  [%expect {|

Working Directory: /.../test/pack-target
Entry Point: index.js
Mode: production
Call Stack: (empty)
Processing File: index.js

EcmaScript6 target is not supported for the regular packer - use flat
  |}]
