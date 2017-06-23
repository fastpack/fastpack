(** Base 64 VQL encode/decode *)

val encode : int list -> bytes
val decode : bytes -> int list
