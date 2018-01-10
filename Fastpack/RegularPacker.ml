module StringSet = Set.Make(String)
module M = Map.Make(String)

open PackerUtil
open Lwt.Infix

module Parser = FastpackUtil.Parser
module Scope = FastpackUtil.Scope
module Visit = FastpackUtil.Visit



let pack ?(with_runtime=true) ?(cache=Cache.fake) ctx channel =

  let analyze _id filename source =
    let ((_, stmts, _) as program), _ = Parser.parse_source source in


    let module Ast = FlowParser.Ast in
    let module Loc = FlowParser.Loc in
    let module S = Ast.Statement in
    let module E = Ast.Expression in
    let module L = Ast.Literal in

    let dependencies = ref [] in
    let dependency_id = ref 0 in
    let workspace = ref (Workspace.of_string source) in
    let ({Workspace.
          patch;
          patch_loc_with;
          remove_loc;
          remove;
          _
        } as patcher) = Workspace.make_patcher workspace
    in

    let program_scope = Scope.of_program stmts Scope.empty in
    let scopes = ref [program_scope] in
    let top_scope () = List.hd !scopes in
    let push_scope scope =
      scopes := scope :: !scopes
    in
    let pop_scope () =
      scopes := List.tl !scopes
    in
    let get_binding name =
      Scope.get_binding name (top_scope ())
    in

    let module_bindings = ref M.empty in
    let n_module = ref 0 in
    let get_module_binding module_request =
      M.get module_request !module_bindings
    in
    let add_module_binding ?(binding=None) module_request =
      let rec gen_module_binding () =
        n_module := !n_module + 1;
        let binding = "$lib" ^ (string_of_int !n_module) in
        if not (Scope.has_binding binding (top_scope ()))
        then binding
        else gen_module_binding ()
      in
      let binding =
        match binding with
        | Some binding -> binding
        | None -> gen_module_binding ()
      in
      begin
        module_bindings := M.add module_request binding !module_bindings;
        binding
      end
    in

    let get_module dep ctx =
      match Module.DependencyMap.get dep ctx with
      | Some m -> m
      | None -> failwith ("Module node found: " ^ dep.request)
    in

    let add_dependency request =
      dependency_id := !dependency_id + 1;
      let dep = {
        Dependency.
        request;
        requested_from_filename = filename;
      } in
      begin
        dependencies := dep::!dependencies;
        dep
      end
    in

    let get_local_name local =
      match get_binding local with
      | Some { typ = Scope.Import { source; remote = Some remote}; _ } ->
        begin
             match get_module_binding source with
             | Some module_binding ->
               module_binding ^ "." ^ remote
             | None ->
               (* TODO: provide better error report*)
               failwith ("Usage of binding before import")
        end
      | _ -> local (* failwith ("Binding not found: " ^ local); *)
    in

    let exports_from_specifiers =
      List.map
        (fun (_,{S.ExportNamedDeclaration.ExportSpecifier.
                  local = (_, local);
                  exported }) ->
           let exported =
             match exported with
             | Some (_, name) -> name
             | None -> local
           in
           exported, get_local_name local
        )
    in

    let define_binding = Printf.sprintf "const %s = %s;" in

    let fastpack_require id filename =
      Printf.sprintf "__fastpack_require__(/* \"%s\" */ \"%s\")"
        filename
        id
    in

    let update_exports ?(property="") exports =
      exports
      |> List.map
        (fun (name, value) ->
           Printf.sprintf
             "Object.defineProperty(exports%s, \"%s\", {get: () => %s});"
             property
             name
             value
        )
      |> String.concat " "
    in

    let enter_function {Visit. parents; _} f =
      push_scope (Scope.of_function parents f (top_scope ()))
    in

    let leave_function _ _ =
      pop_scope ()
    in

    let enter_block {Visit. parents; _} block =
      push_scope (Scope.of_block parents block (top_scope ()))
    in

    let leave_block _ _ =
      pop_scope ()
    in

    let enter_statement {Visit. parents; _} stmt =
      push_scope (Scope.of_statement parents stmt (top_scope ()))
    in

    let leave_statement _ _ =
      pop_scope ()
    in

    let visit_statement visit_ctx ((loc: Loc.t), stmt) =
      let action =
        Mode.patch_statement patcher ctx.Context.mode visit_ctx (loc, stmt)
      in
      match action with
      | Visit.Break ->
        Visit.Break
      | Visit.Continue ->
        let _ = match stmt with
          | S.ImportDeclaration {
              source = (_, { value = request; _ });
              specifiers;
              default;
              _;
            } ->
            let is_skipped =
              List.exists
                (fun e -> String.suffix ~suf:("." ^ e) request)
                ["css"; "less"; "sass"; "woff"; "svg"; "png"; "jpg"; "jpeg";
                 "gif"; "ttf"]
            in
            if is_skipped
            then remove_loc loc
            else
              let dep = add_dependency request in
              patch_loc_with
                loc
                (fun ctx ->
                  let {Module. id = module_id; _} = get_module dep ctx in
                  let namespace =
                    match specifiers with
                    | Some (S.ImportDeclaration.ImportNamespaceSpecifier (_, (_, name))) ->
                      Some name
                    | _ ->
                      None
                  in
                  let has_names = default <> None || specifiers <> None in
                  match has_names, get_module_binding dep.request, namespace with
                  | false, _, _ ->
                    fastpack_require module_id dep.request ^ ";\n"
                  | _, Some binding, Some spec ->
                    define_binding spec binding
                  | _, None, Some spec ->
                    define_binding
                      (add_module_binding ~binding:(Some spec) dep.request)
                      (fastpack_require module_id dep.request)
                  | _, Some _, None ->
                    ""
                  | _, None, None ->
                    define_binding
                      (add_module_binding dep.request)
                      (fastpack_require module_id dep.request)
                );

          | S.ExportNamedDeclaration {
              exportKind = S.ExportValue;
              declaration = Some ((stmt_loc, _) as declaration);
              _
            } ->
            let exports =
              List.map (fun ((_, name), _, _) -> (name, name))
              @@ Scope.names_of_node declaration
            in
            begin
              remove
                loc.start.offset
                (stmt_loc.start.offset - loc.start.offset);
              patch loc._end.offset 0 @@ "\n" ^ update_exports exports ^ "\n";
            end;

          | S.ExportNamedDeclaration {
              exportKind = S.ExportValue;
              declaration = None;
              specifiers = Some (S.ExportNamedDeclaration.ExportSpecifiers specifiers);
              source = None;
            } ->
            patch_loc_with
              loc
              (fun _ -> update_exports @@ exports_from_specifiers specifiers)

          | S.ExportNamedDeclaration {
              exportKind = S.ExportValue;
              declaration = None;
              specifiers = Some (S.ExportNamedDeclaration.ExportSpecifiers specifiers);
              source = Some (_, { value = request; _ });
            } ->
            let dep = add_dependency request in
            let exports_from binding =
              exports_from_specifiers specifiers
              |> List.map (fun (exported, local) -> exported, binding ^ "." ^ local)
              |> update_exports
            in
            patch_loc_with
              loc
              (fun ctx ->
                let {Module. id = module_id; _} = get_module dep ctx in
                match get_module_binding dep.request with
                | Some binding ->
                  exports_from binding
                | None ->
                  let binding = add_module_binding dep.request in
                  define_binding
                    binding
                    (fastpack_require module_id dep.request)
                  ^ "\n"
                  ^ exports_from binding
              );

          | S.ExportNamedDeclaration {
              exportKind = S.ExportValue;
              declaration = None;
              specifiers = Some (
                  S.ExportNamedDeclaration.ExportBatchSpecifier (_, Some (_, spec)));
              source = Some (_, { value = request; _ });
            } ->
            let dep = add_dependency request in
            patch_loc_with
              loc
              (fun ctx ->
                let {Module. id = module_id; _} = get_module dep ctx in
                match get_module_binding dep.request with
                | Some binding ->
                  update_exports [(spec, binding)]
                | None ->
                  let binding = add_module_binding dep.request in
                  define_binding
                    binding
                    (fastpack_require module_id dep.request)
                  ^ "\n"
                  ^ update_exports [(spec, binding)]
              )

          | S.ExportNamedDeclaration {
              exportKind = S.ExportValue;
              declaration = None;
              specifiers = Some (
                  S.ExportNamedDeclaration.ExportBatchSpecifier (_, None));
              source = Some (_, { value = request; _ });
            } ->
            let dep = add_dependency request in
            patch_loc_with
              loc
              (fun ctx ->
                let {Module. id = module_id; scope; _} = get_module dep ctx in
                let exports_from binding =
                  Scope.get_exports scope
                  |> List.map (fun (name, _, _) -> name, binding ^ "." ^ name)
                in
                match get_module_binding dep.request with
                | Some binding ->
                  update_exports @@ exports_from binding
                | None ->
                  let binding = add_module_binding dep.request in
                  define_binding
                    binding
                    (fastpack_require module_id dep.request)
                  ^ "\n"
                  ^ update_exports @@ exports_from binding

              )

          | S.ExportDefaultDeclaration {
              declaration = S.ExportDefaultDeclaration.Expression (expr_loc, _); _
            }
          | S.ExportDefaultDeclaration {
              declaration = S.ExportDefaultDeclaration.Declaration (
                  expr_loc,
                  S.FunctionDeclaration { id=None; _ }
              );
              _
            }
          | S.ExportDefaultDeclaration {
              declaration = S.ExportDefaultDeclaration.Declaration (
                  expr_loc,
                  S.ClassDeclaration { id=None; _ }
              );
              _
            } ->
            patch
              loc.start.offset
              (expr_loc.start.offset - loc.start.offset)
              "exports.default = "

          | S.ExportDefaultDeclaration {
              declaration = S.ExportDefaultDeclaration.Declaration (
                  expr_loc,
                  S.FunctionDeclaration { id = Some (_, id); _ }
              );
              _
            }
          | S.ExportDefaultDeclaration {
              declaration = S.ExportDefaultDeclaration.Declaration (
                  expr_loc,
                  S.ClassDeclaration { id = Some (_, id); _ }
              );
              _
            } ->
            remove
              loc.start.offset
              (expr_loc.start.offset - loc.start.offset);
              patch loc._end.offset 0
                (Printf.sprintf "\nexports.default = %s;\n" id);

          | _ -> ()
        in Visit.Continue
    in

    let visit_expression visit_ctx ((loc: Loc.t), expr) =
      let action =
        Mode.patch_expression patcher ctx.Context.mode visit_ctx (loc,expr)
      in
      match action with
      | Visit.Break -> Visit.Break
      | Visit.Continue ->
        match expr with
        | E.Object { properties } ->
            properties
            |> List.iter
              (fun prop ->
                 match prop with
                  | E.Object.Property (loc, E.Object.Property.Init {
                      key = E.Object.Property.Identifier (_, name) ;
                      shorthand = true;
                      _
                    })  -> patch loc.Loc.start.offset 0 @@ name ^ ": "
                  | _ -> ()
              );
            Visit.Continue

        | E.Import (_, E.Literal { value = L.String request; _ })
        | E.Call {
            callee = (_, E.Identifier (_, "require"));
            arguments = [E.Expression (_, E.Literal { value = L.String request; _ })]
          } ->
          let dep = add_dependency request in
          patch_loc_with loc (fun ctx ->
              let {Module. id = module_id; _} = get_module dep ctx in
              fastpack_require module_id dep.request
            );
          Visit.Break
        | E.Identifier (loc, name) ->
          let () =
            match get_binding name with
            | Some { typ = Scope.Import { source; remote = Some remote}; _ } ->
              patch_loc_with
                loc
                (fun _ ->
                   match get_module_binding source with
                   | Some module_binding ->
                     module_binding ^ "." ^ remote
                   | None ->
                     (* TODO: provide better error report*)
                     failwith ("Usage of binding before import " ^ name ^ " " ^ source ^ " " ^ remote ^ " " ^ filename ^ " " ^ (string_of_int loc.start.offset) ^ " " ^ (string_of_int loc._end.offset))
                )
            | _ -> ()
          in Visit.Break;
        | E.Import _ ->
          failwith "import(_) is supported only with the constant argument"
        | _ ->
          Visit.Continue;
    in

    let handler = {
      Visit.default_visit_handler with
      visit_statement;
      visit_expression;
      enter_function;
      leave_function;
      enter_block;
      leave_block;
      enter_statement;
      leave_statement;
    } in
    Visit.visit handler program;

    (!workspace, !dependencies, program_scope)
  in

  (* Gather dependencies *)
  let rec process ({Context. transpile; _} as ctx) graph (m : Module.t) =
    let m =
      if (not m.cached) then begin
        let source = m.Module.workspace.Workspace.value in
        (* TODO: reafctor this *)
        let transpiled =
          try
            transpile ctx m.filename source
          with
          | FlowParser.Parse_error.Error args ->
            raise (PackError (ctx, CannotParseFile (m.filename, args)))
        in
        let (workspace, dependencies, scope) =
          try
              analyze m.id m.filename transpiled
          with
          | FlowParser.Parse_error.Error args ->
            raise (PackError (ctx, CannotParseFile (m.filename, args)))
        in
        { m with workspace; scope; dependencies; }
      end
      else
        m
    in
    DependencyGraph.add_module graph m;
    let%lwt missing = Lwt_list.filter_map_s (
        fun req ->
          (match%lwt Dependency.resolve req with
           | None ->
             Lwt.return_some req
           | Some resolved ->
             let%lwt dep_module = match DependencyGraph.lookup_module graph resolved with
               | None ->
                 let%lwt m = read_module ctx cache resolved in
                 process { ctx with stack = req :: ctx.stack } graph m
               | Some m ->
                 Lwt.return m
             in
             DependencyGraph.add_dependency graph m (req, Some dep_module);
             Lwt.return_none
          )
      ) m.dependencies
    in
    match missing with
    | [] -> Lwt.return m
    | _ -> raise (PackError (ctx, CannotResolveModules missing))
  in

  (* emit required runtime *)
  let emit_runtime out entry_id =
    (**
       I just copy-pasted that piece of code from webpack

       TODO: Give them proper credits!
    *)
    Lwt_io.write out (Printf.sprintf "
var process = {env: {NODE_ENV: '%s'}};
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
" (Mode.to_string ctx.mode) entry_id)
  in

  let emit graph entry =
    let emit bytes = Lwt_io.write channel bytes in
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
        >> Workspace.write channel workspace ctx
        >> Workspace.write
          (cache.get_channel m.filename (String.length workspace.Workspace.value))
          workspace
          ctx 
        >> emit "},\n"
        >> Lwt.return seen
    in

    (if with_runtime
     then emit_runtime channel entry.Module.id
     else emit @@ "/* Entry point: " ^ entry.Module.id ^ " */\n")
    >> emit "({\n"
    >> emit_module entry
    >>= (fun _ -> emit "\n})\n")
    >> Lwt.return_unit
  in

  let graph = DependencyGraph.empty () in
  let%lwt entry = read_module ctx cache ctx.entry_filename in
  let%lwt entry = process ctx graph entry in
  let%lwt _ = emit graph entry in
  let%lwt () = cache.dump graph in
  Lwt.return_unit


