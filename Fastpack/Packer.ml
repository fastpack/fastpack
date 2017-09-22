module StringSet = Set.Make(String)

type pack_error_reason =
  | CannotReadModule of string

exception PackError of pack_error_reason

let read_module filename =
  let%lwt source =
    try%lwt
      Lwt_io.with_file ~mode:Lwt_io.Input filename Lwt_io.read
    with Unix.Unix_error _ ->
      raise (PackError (CannotReadModule filename))
  in
  Lwt.return {
    Module.
    id = Module.make_id filename;
    filename = filename;
    workspace = Workspace.of_string source;
  }

let read_entry_module filename =
  let pwd = FileUtil.pwd () in
  let filename = FilePath.make_absolute pwd filename in
  read_module filename

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
               (* TODO: emit stub module for the missing dep *)
               Lwt.return (ctx, seen)
             | Some m ->
               let%lwt seen = emit_module ~seen:seen m in
               let ctx = Module.DependencyMap.add dep m ctx in
               Lwt.return (ctx, seen))
          (ctx, seen)
          dependencies
      in
      let%lwt () = emit (Printf.sprintf "\"%s\": function(module, exports, __fastpack_require__) {\n" m.id) in
      let%lwt () = Workspace.write out workspace ctx in
      let%lwt () = emit "},\n" in
      Lwt.return seen
  in

  let%lwt () =
    if with_runtime
    then emit_runtime out entry.Module.id
    else emit @@ "/* Entry point: " ^ entry.Module.id ^ " */\n"
  in
  let%lwt () = emit "({\n" in
  let%lwt _ = emit_module entry in
  let%lwt () = emit "\n})\n" in
  Lwt.return_unit


let rec process graph (m : Module.t) =
  let source = m.Module.workspace.Workspace.value in
  let (workspace, dependencies) = Analyze.analyze m.id m.filename source in
  let m = { m with workspace = workspace } in
  DependencyGraph.add_module graph m;
  let%lwt () = Lwt_list.iter_p (
      fun ({ Dependency. request; _ } as req) ->
        (match%lwt Dependency.resolve req with
         | None ->
           Lwt_io.write Lwt_io.stderr ("ERROR: cannot resolve: " ^ request ^ "\n");
         | Some resolved ->
           let%lwt dep_module = match DependencyGraph.lookup_module graph resolved with
             | None ->
               let%lwt m = read_module resolved in
               process graph m
             | Some m ->
               Lwt.return m
           in
           DependencyGraph.add_dependency graph m (req, Some dep_module);
           Lwt.return_unit
        )
    ) dependencies in
  Lwt.return m

let pack ?(with_runtime=true) channel entry_filename =
  let graph = DependencyGraph.empty () in
  let%lwt entry = read_entry_module entry_filename in
  let%lwt entry = process graph entry in
  let%lwt () = emit ~with_runtime channel graph entry in
  Lwt.return_unit

let pack_main entry =
  Lwt_main.run (pack Lwt_io.stdout entry)
