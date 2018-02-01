(function() {
var __DEV__ = false;

/* builtin$$COLON$$__fastpack_runtime__ */

let $n__builtin$$COLON$$__fastpack_runtime__ = { exports: {}};
function $i__builtin$$COLON$$__fastpack_runtime____applyDecorator(decorator, proto, property, descriptor) {
  let ret = decorator(proto, property, descriptor);
  // TODO: assert all descriptor properties;
  return ret;
}

function $i__builtin$$COLON$$__fastpack_runtime____decorateProperty(cls, property, decorators) {
  let proto = cls.prototype;
  let descriptor = Object.assign(
    {},
    Object.getOwnPropertyDescriptor(proto, property)
  );

  // TODO: Babel also accounts for descriptor.initializer. Is it needed?
  descriptor = decorators.reverse().reduce(
    (descriptor, decorator) => $i__builtin$$COLON$$__fastpack_runtime____applyDecorator(decorator, proto, property, descriptor),
    descriptor
  );

  Object.defineProperty(proto, property, descriptor);
}

$n__builtin$$COLON$$__fastpack_runtime__.exports = {
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
      ({method, decorators}) => $i__builtin$$COLON$$__fastpack_runtime____decorateProperty(cls, method, decorators)
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

/* builtin$$COLON$$path */


const $n__builtin$$COLON$$path = { exports: {} };

/* builtin$$COLON$$module */


const $n__builtin$$COLON$$module = { exports: {} };

/* esm */


const $e__esm__default = $n__builtin$$COLON$$path.exports.delimiter;

const $n__esm = { exports: {default: $e__esm__default} };

/* index */

const $i__index__$__fpack__ = ($n__builtin$$COLON$$__fastpack_runtime__.exports);
const $i__index__path = ($n__builtin$$COLON$$path.exports);
const $i__index__module = ($n__builtin$$COLON$$module.exports);
const $i__index__esm = ($n__esm.exports);
const {delimiter: $i__index__delimiter} = $i__index__path,
  $i__index__rest = $i__index__$__fpack__.omitProps($i__index__path, ["delimiter"]);
console.log($i__index__path, $i__index__module, $i__index__delimiter, $i__index__rest, $i__index__esm);
// The following test makes sure that builtin transpiler strips type annotations
// from inside JSX
const $i__index__Component = props => React.createElement("div", null, item => {
    
  }
  );

const $n__index = { exports: {} };
})()
