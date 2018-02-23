
function decorator1(proto, property, descriptor) {
  let oldValue = descriptor.value;
  descriptor.value = function() {
    let ret = oldValue.call(this);
    return `@decorator1 ${ret}`;
  }
  return descriptor;
}

function decorator2(proto, property, descriptor) {
  let oldValue = descriptor.value;
  descriptor.value = function() {
    let ret = oldValue.call(this);
    return `@decorator2 ${ret}`;
  }
  return descriptor;
}

function classDecorator1(cls) {
  cls.staticProp = `@classDecorator1 ${cls.staticProp}`;
  return cls;
}

function classDecorator2(cls) {
  cls.staticProp = `@classDecorator2 ${cls.staticProp}`;
  return cls;
}

@classDecorator2
@classDecorator1
class Test {
  prop = "instance property";
  static staticProp = "class property";

  @decorator2
  @decorator1
  method() {
    return "method";
  }
}

let {test, ...rest} = {test: new Test(), a: 1, b: 2, c: 3};

document.body.innerHTML = `
<div>Static property: <b>${Test.staticProp}</b></div>
<div>Property: <b>${test.prop}</b></div>
<div>method: <b>${test.method()}</b></div>
<div>...rest: <b>${JSON.stringify(rest)}</b></div>
`;
