open Util

let%expect_test "pack-flat-reexport.js" =
  run_with_filename pack_flat_prod "pack-flat-reexport/index.js";
  (* Printf.printf "%s" @@ Unix.getcwd (); *)
  [%expect {|
(function() {

/* b */

let $e__b__b = 1;

const $n__b = { exports: {b: $e__b__b} };

/* a */



const $n__a = { exports: {a: $e__b__b} };

/* index */



console.log($e__b__b);

const $n__index = { exports: {} };
})()
  |}]
