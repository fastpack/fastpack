open Util

let%expect_test "pack-flat-utf8" =
  run_with_filename pack_flat_dev "pack-utf8/index.js";
  (* Printf.printf "%s" @@ Unix.getcwd (); *)
  [%expect {|
(function() {

/* a */

let $e__a__a1 = "Тест";
let $e__a__a2 = "Привет, мир";
let $e__a__a3 = "哈囉世界";
let $e__a__a4 = "💩";
const $e__a__default = {a1: $e__a__a1, a2: $e__a__a2, a3: $e__a__a3, a4: $e__a__a4};

const $n__a = { exports: {default: $e__a__default, a1: $e__a__a1, a2: $e__a__a2, a3: $e__a__a3, a4: $e__a__a4} };

/* index */


const $e__index__default = function() {
  console.log("Русский", "development",
              "разработка");
}

const $n__index = { exports: {default: $e__index__default} };
})()
  |}]
