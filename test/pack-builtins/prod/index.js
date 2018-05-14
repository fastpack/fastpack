(function() {

/* $fp$runtime */

let $n__$fp$runtime = { id: "$fp$runtime", exports: {}};

function $i__$fp$runtime__applyDecorator(decorator, proto, property, descriptor) {
  var ret = decorator(proto, property, descriptor);
  // TODO: assert all descriptor properties;
  return ret;
}

function $i__$fp$runtime__decorateProperty(cls, property, decorators) {
  var proto = cls.prototype;
  var descriptor = Object.assign(
    {},
    Object.getOwnPropertyDescriptor(proto, property)
  );

  for(var i = 0, reversed = decorators.reverse(), l = reversed.length;
      i < l;
      i++) {
    descriptor = $i__$fp$runtime__applyDecorator(reversed[i], proto, property, descriptor);
  }

  Object.defineProperty(proto, property, descriptor);
}

$n__$fp$runtime.exports = {
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
      $i__$fp$runtime__decorateProperty(cls,
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

try{$n__$fp$runtime.exports.__esModule = $n__$fp$runtime.exports.__esModule || false;}catch(_){}

/* builtin$$B$$esm */

let $n__builtin$$B$$esm = { id: "builtin$$B$$esm", exports: {}};
const $e__builtin$$B$$esm__default = "hello, world!";

try{$n__builtin$$B$$esm.exports.default = $e__builtin$$B$$esm__default;
$n__builtin$$B$$esm.exports.__esModule = $n__builtin$$B$$esm.exports.__esModule || true;}catch(_){}

/* builtin$$B$$index */

let $n__builtin$$B$$index = { id: "builtin$$B$$index", exports: {}};
const $i__builtin$$B$$index__$__fpack__ = ($n__$fp$runtime.exports);
const $i__builtin$$B$$index__esm = ($n__builtin$$B$$esm.exports);
const {delimiter: $i__builtin$$B$$index__delimiter} = path,
  $i__builtin$$B$$index__rest = $i__builtin$$B$$index__$__fpack__.omitProps(path, ["delimiter"]);
console.log(path, $n__builtin$$B$$index, $i__builtin$$B$$index__delimiter, $i__builtin$$B$$index__rest, $i__builtin$$B$$index__esm);
// The following test makes sure that builtin transpiler strips type annotations
// from inside JSX
const $i__builtin$$B$$index__Component = props => React.createElement("div", null, item => {
    
  }
  );

try{$n__builtin$$B$$index.exports.__esModule = $n__builtin$$B$$index.exports.__esModule || false;}catch(_){}

/* $fp$main */

let $n__$fp$main = { id: "$fp$main", exports: {}};


try{$n__$fp$main.exports.__esModule = $n__$fp$main.exports.__esModule || true;}catch(_){}
})()
