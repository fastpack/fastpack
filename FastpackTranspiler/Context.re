module Scope = FastpackUtil.Scope;

type t = {
  gen_id: (string, unit) => string,
  gen_binding: Scope.t => string,
  require_runtime: unit => unit,
  is_runtime_required: unit => bool,
};

let create = () => {
  let counter = ref(0);
  let runtime_required = ref(false);
  let gen_id = (prefix, ()) => {
    counter := 1 + counter^;
    prefix ++ string_of_int(counter^);
  };

  let is_runtime_required = () => runtime_required^;

  let require_runtime = () => runtime_required := true;

  let rec gen_binding = scope => {
    let name = gen_id("__fpack__", ());
    if (Scope.has_binding(name, scope)) {
      gen_binding(scope);
    } else {
      name;
    };
  };

  {gen_id, gen_binding, require_runtime, is_runtime_required};
};
