module Scope = FastpackUtil.Scope;

module DependencySet = Set.Make(String);

type t = {
  gen_id: (string, unit) => string,
  gen_binding: Scope.t => string,
  require_runtime_helper: string => unit,
  get_runtime_helpers: unit => DependencySet.t,
};

let create = () => {
  let counter = ref(0);
  let dependencies = ref(DependencySet.empty);
  let gen_id = (prefix, ()) => {
    counter := 1 + counter^;
    prefix ++ string_of_int(counter^);
  };

  let get_runtime_helpers = () => dependencies^;

  let require_runtime_helper = name =>
    dependencies := dependencies^ |> DependencySet.add(name);

  let rec gen_binding = scope => {
    let name = gen_id("__fpack__", ());
    if (Scope.has_binding(name, scope)) {
      gen_binding(scope);
    } else {
      name;
    };
  };

  {gen_id, gen_binding, require_runtime_helper, get_runtime_helpers};
};
