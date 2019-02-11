module Error = Error;
module ReactJSX = ReactJSX;
module StripFlow = StripFlow;
module Class = Class;
module ObjectSpread = ObjectSpread;

/* TODO: make sure it is ES2015 compatible */
let runtime = {|

function applyDecorator(decorator, proto, property, descriptor) {
  var ret = decorator(proto, property, descriptor);
  // TODO: assert all descriptor properties;
  return ret;
}

function decorateProperty(cls, property, decorators) {
  var proto = cls.prototype;
  var descriptor = Object.assign(
    {},
    Object.getOwnPropertyDescriptor(proto, property)
  );

  for(var i = 0, reversed = decorators.reverse(), l = reversed.length;
      i < l;
      i++) {
    descriptor = applyDecorator(reversed[i], proto, property, descriptor);
  }

  Object.defineProperty(proto, property, descriptor);
}

module.exports = {
  omitProps: function(target, props) {
    var ret = {};
    for(var prop in target) {
      if(target.hasOwnProperty(prop) && props.indexOf(prop) == -1) {
        ret[prop] = target[prop];
      }
    }
    return ret;
  },

  defineClass: function(cls, statics, classDecorators, propertyDecorators) {
    for(var i = 0, l = propertyDecorators.length; i < l; i++) {
      decorateProperty(cls,
                       propertyDecorators[i].method,
                       propertyDecorators[i].decorators);
    }

    for(var i = 0, l = statics.length; i < l; i++) {
      Object.defineProperty(cls, statics[i].name, {
        configurable: true,
        enumerable: true,
        writable: true,
        value: statics[i].value
      })
    }

    var _cls = cls;
    classDecorators = classDecorators.reverse();
    for(var i = 0; i < classDecorators.length; i++) {
      _cls = classDecorators[i](_cls);
    }
    return _cls;
  }
};
|};

/** Transpile Ast.program node using a list of transpilers */

let transpile = (transpilers, program) => {
  let context = Context.create();
  let (program', modified) =
    List.fold_left(
      ((program, modified), transpile) =>
        transpile(context, program, modified),
      (program, false),
      transpilers,
    );

  if (!context.is_runtime_required()) {
    (program', modified ? None : Some(program));
  } else {
    let (loc, stmts, comments) = program';
    (
      (loc, [FastpackUtil.AstHelper.require_runtime, ...stmts], comments),
      None,
    );
  };
};

/** Transpile source code using a list of transpilers */

let transpile_source = (transpilers, source) => {
  let (program, _) = FastpackUtil.Parser.parse_source(source);
  let (program', modified) = transpile(transpilers, program);
  switch (modified) {
  | Some(program) => (source, Some(program))
  | None => (FastpackUtil.Printer.print(program'), None)
  };
};
