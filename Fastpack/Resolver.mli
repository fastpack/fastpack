module Mock : sig
  type t = Empty
         | Mock of string
  val to_string : t -> string
  val parse : string -> (bool * (string * t), [> `Msg of string ]) result
  val print : Format.formatter -> 'a * (string * t) -> unit
end

type t = {
  resolve : basedir:string -> string -> (Module.location * string  list) Lwt.t;
}

exception Error of string

val make : project_root:string ->
           current_dir:string ->
           mock:(string * Mock.t) list ->
           node_modules_paths:string list ->
           extensions:string list ->
           preprocessor:Preprocessor.t ->
           cache:Cache.t ->
           t
