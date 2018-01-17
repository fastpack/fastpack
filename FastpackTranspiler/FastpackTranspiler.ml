module Error = Error
module ReactJSX = ReactJSX
module StripFlow = StripFlow
module Class = Class
module ObjectSpread = ObjectSpread

let runtime = "
function applyDecorator(decorator, proto, property, descriptor) {
  let ret = decorator(proto, property, descriptor);
  // TODO: assert all descriptor properties;
  return ret;
}

function decorateProperty(cls, property, decorators) {
  let proto = cls.prototype;
  let descriptor = Object.assign(
    {},
    Object.getOwnPropertyDescriptor(proto, property)
  );

  // TODO: Babel also accounts for descriptor.initializer. Is it needed?
  descriptor = decorators.reverse().reduce(
    (descriptor, decorator) => applyDecorator(decorator, proto, property, descriptor),
    descriptor
  );

  Object.defineProperty(proto, property, descriptor);
}

module.exports = {
  omitProps(target, props) {
    let ret = {};
    for(let prop in target) {
      if(target.hasOwnProperty(prop) && props.indexOf(prop) == -1) {
        ret[prop] = target[prop];
      }
    }
    return ret;
  },

  defineClass(cls, statics, classDecorators, propertyDecorators) {
    propertyDecorators.forEach(
      ({method, decorators}) => decorateProperty(cls, method, decorators)
    );

    statics.forEach(({name, value}) =>
      Object.defineProperty(cls, name, {
        configurable: true,
        enumerable: true,
        writable: true,
        value: value
      })
    );
    let _cls = cls;
    classDecorators = classDecorators.reverse();
    for(let i = 0; i < classDecorators.length; i++) {
      _cls = classDecorators[i](_cls);
    }
    return _cls;

    //return classDecorators.reverse().reduce(decorator => decorator(cls), cls);
  }
};
"

(** Transpile Ast.program node using a list of transpilers *)
let transpile transpilers program =
  let context = Context.create () in
  let program = List.fold_left
      (fun program transpile -> transpile context program)
      program
      transpilers
  in
  if not (context.is_runtime_required ())
  then
    program
  else
    let loc, stmts, comments = program in
    (loc, FastpackUtil.AstHelper.require_runtime :: stmts, comments)


(** Transpile source code using a list of transpilers *)
let transpile_source transpilers source =
  let program, _ = FastpackUtil.Parser.parse_source source in
  FastpackUtil.Printer.print (transpile transpilers program)
