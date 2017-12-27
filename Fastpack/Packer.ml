module StringSet = Set.Make(String)
open Lwt.Infix

type ctx = {
  package_dir : string;
  stack : Dependency.t list;
}

let ctx_to_string { package_dir; stack } =
  Printf.sprintf "Working directory: %s\n" package_dir
  ^ "\nCall stack:\n"
  ^ String.concat "\t\n" @@ List.map Dependency.to_string stack


exception PackError of ctx * Error.reason

let read_module ctx filename =
  (* TODO: uncomment this when the main directory will be set to the correct value *)
  (* if not (FilePath.is_subdir filename ctx.package_dir) *)
  (* then raise (PackError (ctx, CannotLeavePackageDir filename)); *)
  let%lwt source =
    match Str.string_match (Str.regexp "^builtin:") filename 0 with
    | true ->
      Lwt.return ""
    | false ->
      try%lwt
        Lwt_io.with_file ~mode:Lwt_io.Input filename Lwt_io.read
      with Unix.Unix_error _ ->
        raise (PackError (ctx, CannotReadModule filename))
  in
  Lwt.return {
    Module.
    (* TODO: make more deacriptive module id *)
    id = Module.make_id (FilePath.basename filename) filename;
    filename = filename;
    workspace = Workspace.of_string source;
    scope = Scope.empty;
  }

let read_entry_module filename =
  let filename = FilePath.make_absolute (FileUtil.pwd ()) filename in
  (* TODO: how to identify the package dir? closest parent with package.json? Yes! *)
  let package_dir = FilePath.dirname filename in
  let ctx = { package_dir; stack = []; } in
  let%lwt m = read_module ctx filename in
  Lwt.return (ctx, m)

let emit_runtime out entry_id =
  (**
     I just copy-pasted that piece of code from webpack

     TODO: Give them proper credits!
  *)
  Lwt_io.write out (Printf.sprintf "
(function(modules) {
  // The module cache
  var installedModules = {};

  // The require function
  function __fastpack_require__(moduleId) {

    // Check if module is in cache
    if(installedModules[moduleId]) {
      return installedModules[moduleId].exports;
    }
    // Create a new module (and put it into the cache)
    var module = installedModules[moduleId] = {
      i: moduleId,
      l: false,
      exports: {}
    };

    // Execute the module function
    modules[moduleId].call(module.exports, module, module.exports, __fastpack_require__);

    // Flag the module as loaded
    module.l = true;

    // TODO: is it sustainable?
    if(module.exports.default === undefined) {
      module.exports.default = module.exports;
    }

    // Return the exports of the module
    return module.exports;
  }

  // expose the modules object
  __fastpack_require__.m = modules;

  // expose the module cache
  __fastpack_require__.c = installedModules;

  // define getter function for harmony exports
  __fastpack_require__.d = function(exports, name, getter) {
    if(!__fastpack_require__.o(exports, name)) {
      Object.defineProperty(exports, name, {
        configurable: false,
        enumerable: true,
        get: getter
      });
    }
  };

  // getDefaultExport function for compatibility with non-harmony modules
  __fastpack_require__.n = function(module) {
    var getter = module && module.__esModule ?
      function getDefault() { return module['default']; } :
      function getModuleExports() { return module; };
    __fastpack_require__.d(getter, 'a', getter);
    return getter;
  };

  // Object.prototype.hasOwnProperty.call
  __fastpack_require__.o = function(object, property) { return Object.prototype.hasOwnProperty.call(object, property); };

  // Public path
  __fastpack_require__.p = '';

  // Load entry module and return exports
  return __fastpack_require__(__fastpack_require__.s = '%s');
})
" entry_id)

let emit ?(with_runtime=true) out graph entry =
  let emit bytes = Lwt_io.write out bytes in
  let rec emit_module ?(seen=StringSet.empty) m =
    if StringSet.mem m.Module.id seen
    then Lwt.return seen
    else
      let seen = StringSet.add m.Module.id seen in
      let workspace = m.Module.workspace in
      let ctx = Module.DependencyMap.empty in
      let dependencies = DependencyGraph.lookup_dependencies graph m in
      let%lwt (ctx, seen) = Lwt_list.fold_left_s
          (fun (ctx, seen) (dep, m) ->
             match m with
             | None ->
               let%lwt () = Lwt_io.write Lwt_io.stderr "None" in
               (* TODO: emit stub module for the missing dep *)
               Lwt.return (ctx, seen)
             | Some m ->
               let%lwt seen = emit_module ~seen:seen m in
               let ctx = Module.DependencyMap.add dep m ctx in
               Lwt.return (ctx, seen))
          (ctx, seen)
          dependencies
      in
      emit (Printf.sprintf
              "\"%s\": function(module, exports, __fastpack_require__) {\n"
              m.id)
      >> Workspace.write out workspace ctx
      >> emit "},\n"
      >> Lwt.return seen
  in

  (if with_runtime
   then emit_runtime out entry.Module.id
   else emit @@ "/* Entry point: " ^ entry.Module.id ^ " */\n")
  >> emit "({\n"
  >> emit_module entry
  >>= (fun _ -> emit "\n})\n")
  >> Lwt.return_unit

let rec process transpile graph ctx (m : Module.t) =
  let source = m.Module.workspace.Workspace.value in
  let transpiled = transpile ctx.package_dir m.filename source in
  let (workspace, dependencies, scope) =
    try
        Analyze.analyze m.id m.filename transpiled
    with
    | FlowParser.Parse_error.Error args ->
      raise (PackError (ctx, CannotParseFile (m.filename, args)))
  in
  let m = { m with workspace; scope; } in
  DependencyGraph.add_module graph m;
  let%lwt missing = Lwt_list.filter_map_s (
      fun req ->
        (match%lwt Dependency.resolve req with
         | None ->
           Lwt.return_some req
         | Some resolved ->
           let%lwt dep_module = match DependencyGraph.lookup_module graph resolved with
             | None ->
               let%lwt m = read_module ctx resolved in
               process transpile graph { ctx with stack = req :: ctx.stack } m
             | Some m ->
               Lwt.return m
           in
           DependencyGraph.add_dependency graph m (req, Some dep_module);
           Lwt.return_none
        )
    ) dependencies
  in
  match missing with
  | [] -> Lwt.return m
  | _ -> raise (PackError (ctx, CannotResolveModules missing))


let pack ?(with_runtime=true) transpile channel entry_filename =
  let graph = DependencyGraph.empty () in
  let%lwt (ctx, entry) = read_entry_module entry_filename in
  let%lwt entry = process transpile graph ctx entry in
  let%lwt _ = emit ~with_runtime channel graph entry in
  Lwt.return_unit

let pack_main ?(transpile=(fun _ _ p -> p)) entry =
  Lwt_main.run (pack transpile Lwt_io.stdout entry)
