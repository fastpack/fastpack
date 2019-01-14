open Test

let%expect_test "transpile-class.js" =
  test transpile "transpile-class.js";
  [%expect_exact {|const $__fpack__ = require("$fp$runtime");
/* nothing to transform */
class CC {
  method1() {
    
  }
  
  constructor() {
    
  }
  
  method2() {
    
  }
  
}/* no costructor */
class C {
  constructor( ...args) {
    Object.defineProperty(this, "state", {"configurable": true, "enumerable": true, "writable": true, "value": 1});
    
  }
  
}/* constructor */
class C1 {
  constructor() {
    Object.defineProperty(this, "x", {"configurable": true, "enumerable": true, "writable": true, "value": 1});
    Object.defineProperty(this, "y", {"configurable": true, "enumerable": true, "writable": true, "value": 2});
    this.z = this.x + this.y;
    
  }
  
}/* constructor & super */
class C2 extends C1 {
  method() {
    
  }
  
  constructor() {
    debugger;
    super();
    Object.defineProperty(this, "onClick", {"configurable": true, "enumerable": true, "writable": true, "value": e => {
      console.log('hello');
      
    }
    });
    Object.defineProperty(this, "onMouseMove", {"configurable": true, "enumerable": true, "writable": true, "value": e => {
      console.log(e);
      
    }
    });
    Object.defineProperty(this, "doSomethingUseful", {"configurable": true, "enumerable": true, "writable": true, "value": () => 42});
    this.onClick();
    
  }
  
}let C3 = $__fpack__.defineClass(class /* class decorators */
  C3 {
    
  }, [], [c => c, dec], []);
let C4 = $__fpack__.defineClass(class /* method decorators */
  C4 {
    method1() {
      
    }
    
    method2() {
      
    }
    
  }, [], [], [{"method": "method1", "decorators": [dec]}, {"method": "method2", "decorators": [m => m, dec2]}]);
/* class expressions */
(class  {
  constructor( ...args) {
    Object.defineProperty(this, "prop1", {"configurable": true, "enumerable": true, "writable": true, "value": void 0});
    
  }
  
});
let C5 = $__fpack__.defineClass(class  {
    constructor( ...args) {
      Object.defineProperty(this, "prop1", {"configurable": true, "enumerable": true, "writable": true, "value": void 0});
      
    }
    
  }, [{"name": "prop2", "value": void 0}], [], []);
let C6 = $__fpack__.defineClass(class /* all of the above */
  C6 extends C5 {
    method1() {
      
    }
    
    methodDecorated2() {
      
    }
    
    constructor() {
      before_super1();
      before_super2();
      super();
      Object.defineProperty(this, "prop_no_value", {"configurable": true, "enumerable": true, "writable": true, "value": void 0});
      Object.defineProperty(this, "prop_int", {"configurable": true, "enumerable": true, "writable": true, "value": 1});
      Object.defineProperty(this, "prop_func", {"configurable": true, "enumerable": true, "writable": true, "value": x => x + 1});
      after_super_and_props();
      
    }
    
    methodDecorated3() {
      
    }
    
  }, [{"name": "static_prop", "value": void 0}], [cls, cls => cls], [{"method": "methodDecorated2", "decorators": [m => m]}, {"method": "methodDecorated3", "decorators": [mDec1, mDec2]}]);
/* constructor & super with arguments */
class MyComponent extends Component {
  constructor( ...args) {
    super(...args);
    Object.defineProperty(this, "state", {"configurable": true, "enumerable": true, "writable": true, "value": {content: this.props.content}});
    
  }
  
}|}]
