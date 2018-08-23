module Error = Error;
module ReactJSX = ReactJSX;
module StripFlow = StripFlow;
module Class = Class;
module ObjectSpread = ObjectSpread;

/* TODO: make sure it is ES2015 compatible */
let runtime = "\nfunction applyDecorator(decorator, proto, property, descriptor) {\n  var ret = decorator(proto, property, descriptor);\n  // TODO: assert all descriptor properties;\n  return ret;\n}\n\nfunction decorateProperty(cls, property, decorators) {\n  var proto = cls.prototype;\n  var descriptor = Object.assign(\n    {},\n    Object.getOwnPropertyDescriptor(proto, property)\n  );\n\n  for(var i = 0, reversed = decorators.reverse(), l = reversed.length;\n      i < l;\n      i++) {\n    descriptor = applyDecorator(reversed[i], proto, property, descriptor);\n  }\n\n  Object.defineProperty(proto, property, descriptor);\n}\n\nmodule.exports = {\n  omitProps: function(target, props) {\n    var ret = {};\n    for(var prop in target) {\n      if(target.hasOwnProperty(prop) && props.indexOf(prop) == -1) {\n        ret[prop] = target[prop];\n      }\n    }\n    return ret;\n  },\n\n  defineClass: function(cls, statics, classDecorators, propertyDecorators) {\n    for(var i = 0, l = propertyDecorators.length; i < l; i++) {\n      decorateProperty(cls,\n                       propertyDecorators[i].method,\n                       propertyDecorators[i].decorators);\n    }\n\n    for(var i = 0, l = statics.length; i < l; i++) {\n      Object.defineProperty(cls, statics[i].name, {\n        configurable: true,\n        enumerable: true,\n        writable: true,\n        value: statics[i].value\n      })\n    }\n\n    var _cls = cls;\n    classDecorators = classDecorators.reverse();\n    for(var i = 0; i < classDecorators.length; i++) {\n      _cls = classDecorators[i](_cls);\n    }\n    return _cls;\n  }\n};\n";

/** Transpile Ast.program node using a list of transpilers */

let transpile = (transpilers, program) => {
  let context = Context.create();
  let program =
    List.fold_left(
      (program, transpile) => transpile(context, program),
      program,
      transpilers,
    );

  if (!context.is_runtime_required()) {
    program;
  } else {
    let (loc, stmts, comments) = program;
    (loc, [FastpackUtil.AstHelper.require_runtime, ...stmts], comments);
  };
};

/** Transpile source code using a list of transpilers */

let transpile_source = (transpilers, source) => {
  let (program, _) = FastpackUtil.Parser.parse_source(source);
  FastpackUtil.Printer.print(transpile(transpilers, program));
};
