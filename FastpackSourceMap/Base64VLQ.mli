(** Base 64 VQL encode/decode *)

val encode_int : Buffer.t -> int -> unit
val encode : int list -> bytes
val decode : bytes -> int list
