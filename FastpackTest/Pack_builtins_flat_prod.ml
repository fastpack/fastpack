open Util

let%expect_test "pack-builtins-flat-prod.js" =
  run_with_filename pack_transpile_flat_prod "pack-builtins/index.js";
  (* Printf.printf "%s" @@ Unix.getcwd (); *)
  [%expect {|
  |}]
