module StringSet = Set.Make(String);
/*
 Watcher logic:
 if build is successful, return ctx and new list of files to track
 if build is not successful, return ctx and previous list of files to track
 */
let rebuild = (~filesChanged: StringSet.t, ~pack, prev_result) => {
  let start_time = Unix.gettimeofday();
  let (result, ctx: Context.t, filesWatched: StringSet.t) =
    switch (prev_result) {
    | Error((ctx, filesWatched)) => (`Error, ctx, filesWatched)
    | Ok((ctx, filesWatched)) => (`Ok, ctx, filesWatched)
    };
  StringSet.iter(ctx.cache.remove, filesChanged);
  switch (StringSet.(inter(filesChanged, filesWatched) |> elements)) {
  | [] => Lwt.return(prev_result)
  | filesChanged =>
    let (runPack, graph, current_location) =
      switch (result) {
      | `Error => (true, None, None)
      | `Ok =>
        switch (
          DependencyGraph.get_changed_module_locations(
            ctx.graph,
            filesChanged,
          )
          |> Module.LocationSet.elements
        ) {
        | [] => (false, None, None)
        | [location] =>
          DependencyGraph.remove_module(ctx.graph, location);
          (true, Some(ctx.graph), Some(location));
        | _ => (true, None, None)
        }
      };
    let%lwt newResult =
      if (runPack) {
        pack(~current_location, ~graph, ~initial=false, ~start_time);
      } else {
        switch (result) {
        | `Ok => Lwt.return_ok(ctx)
        | `Error => Lwt.return_error(ctx)
        };
      };
    switch (newResult) {
    | Ok(ctx) => Lwt.return_ok((ctx, DependencyGraph.get_files(ctx.graph)))
    | Error((ctx: Context.t)) =>
      Lwt.return_error((
        ctx,
        StringSet.union(DependencyGraph.get_files(ctx.graph), filesWatched),
      ))
    };
  };
};
