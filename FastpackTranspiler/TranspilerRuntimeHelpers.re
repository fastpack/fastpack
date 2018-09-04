module Helpers = Map.Make(String);

let helpers: ref(Helpers.t(string)) = ref(Helpers.empty);

let register = (name, source) =>
  helpers := helpers^ |> Helpers.add(name, source);

exception RuntimeHelperNotRegistered(string);

let get = name =>
  try (helpers^ |> Helpers.find(name)) {
  | Not_found =>
    raise(
      RuntimeHelperNotRegistered(
        "FastpackTranspiler: runtime helper `" ++ name ++ "` is not registered",
      ),
    )
  };
