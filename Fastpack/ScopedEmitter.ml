module MLSet = Module.LocationSet 
module StringSet = Set.Make(String)
module FS = FastpackUtil.FS

let emit_module_files (ctx : Context.t) (m : Module.t) =
  Lwt_list.iter_s
    (fun (filename, content) ->
      let path = FS.abs_path ctx.output_dir filename in
      let%lwt () = FS.makedirs (FilePath.dirname path) in
      Lwt_io.(with_file
                ~mode:Lwt_io.Output
                ~perm:0o640
                ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
                path
                (fun ch -> write ch content)
             )
    )
    m.files

let to_eval s =
  let json = Yojson.to_string (`String s) in
  String.(sub json 1 (length json - 2))

let run (ctx : Context.t) output_channel =
  (* emit required runtime *)
  let emit_runtime out prefix entry_id =
    Lwt_io.write out
    @@ Printf.sprintf
"
// This function is a modified version of the one created by the Webpack project
global = window;
process = { env: {} };
%s(function(modules) {
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
      id: moduleId,
      l: false,
      exports: {}
    };

    // Execute the module function
    modules[moduleId].call(
      module.exports,
      module,
      module.exports,
      __fastpack_require__,
      __fastpack_import__
    );

    // Flag the module as loaded
    module.l = true;

    // Return the exports of the module
    return module.exports;
  }

  function __fastpack_import__(moduleId) {
    if (!window.Promise) {
      throw 'window.Promise is undefined, consider using a polyfill';
    }
    return new Promise(function(resolve, reject) {
      try {
        resolve(__fastpack_require__(moduleId));
      } catch (e) {
        reject(e);
      }
    });
  }

  __fastpack_require__.m = modules;
  __fastpack_require__.c = installedModules;
  __fastpack_require__.omitDefault = function(moduleVar) {
    var keys = Object.keys(moduleVar);
    var ret = {};
    for(var i = 0, l = keys.length; i < l; i++) {
      var key = keys[i];
      if (key !== 'default') {
        ret[key] = moduleVar[key];
      }
    }
    return ret;
  }
  return __fastpack_require__(__fastpack_require__.s = '%s');
})
" prefix entry_id
  in

  let emitted_modules = ref (MLSet.empty) in
  let emit graph entry =
    let emit bytes = Lwt_io.write output_channel bytes in
    let dep_map = DependencyGraph.to_dependency_map graph in
    let rec emit_module (m : Module.t) =
      if MLSet.mem m.location !emitted_modules
      then Lwt.return_unit
      else begin
        emitted_modules := MLSet.add m.location !emitted_modules;
        let%lwt () = emit_module_files ctx m in
        let workspace = m.Module.workspace in
        let dependencies = DependencyGraph.lookup_dependencies graph m in
        let%lwt () =
          Lwt_list.iter_s
            (fun (_, m) ->
               match m with
               | None -> Lwt.return_unit
               | Some m -> emit_module m
            )
            dependencies
        in
        let%lwt () =
          m.id
          |> Printf.sprintf "\"%s\": function(module, exports, __fastpack_require__, __fastpack_import__) {\n"
          |> emit
        in
        let%lwt () = emit "eval(\"" in
        let modify =
          match m.state with
          | Module.Analyzed -> fun s -> s
          | _ -> to_eval
        in
        let%lwt content =
          Workspace.write
            ~modify
            ~output_channel
            ~workspace
            ~ctx:(m, dep_map) in
        let%lwt () =
          Module.location_to_string ~base_dir:(Some ctx.current_dir) m.location
          |> Printf.sprintf "\\n//# sourceURL=fpack:///%s\");"
          |> emit
        in
        let m = { m with state = Module.Analyzed } in
        let () =
          match m.location with
          | Module.File _ ->
            ctx.cache.modify_content m content
          | _ ->
            ()
        in
        let () =
          DependencyGraph.add_module
            graph
            { m with workspace = Workspace.of_string content }
        in
        let%lwt () = emit "\n},\n" in
        Lwt.return_unit
      end
    in

    let export =
      match ctx.target with
      | Target.CommonJS ->
        "module.exports = "
      | _ ->
        ""
    in

    let%lwt () = emit_runtime output_channel export entry.Module.id in
    let%lwt () = emit "({\n" in
    let%lwt _ = emit_module entry in
    let%lwt () = emit "\n});\n" in
    Lwt.return_unit
  in

  let {Context. entry_location; graph; _ } = ctx in
  let entry =
    match DependencyGraph.lookup_module graph entry_location with
    | Some m -> m
    | None -> Error.ie (Module.location_to_string entry_location ^ " not found in the graph")
  in
  let%lwt _ = emit graph entry in
  Lwt.return (
    !emitted_modules,
    Lwt_io.position output_channel |> Int64.to_int
  )
  (* DependencyGraph.cleanup ctx.graph emitted_modules; *)
  (* Lwt_io.position output_channel |> Int64.to_int |> Lwt.return *)

let emit (ctx : Context.t) =
  let temp_file =
    Filename.temp_file ~temp_dir:ctx.output_dir ".fpack" ".bundle.js"
  in
  Lwt.finalize
    (fun () ->
      let%lwt emitted_modules, size =
        Lwt_io.with_file
          ~mode:Lwt_io.Output
          ~perm:0o640
          ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
          temp_file
          (run ctx)
      in
      let%lwt () = Lwt_unix.rename temp_file ctx.output_file in
      Lwt.return (emitted_modules, [{Reporter. name = ctx.output_file; size}])
    )
    (fun () ->
       if%lwt Lwt_unix.file_exists temp_file
       then Lwt_unix.unlink temp_file;
    )

let update_graph () =
  failwith "not implemented"
