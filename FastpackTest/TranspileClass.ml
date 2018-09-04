open Test

let%expect_test "transpile-class.js" =
  test transpile "transpile-class.js";
  [%expect_exact {|const $fp$runtime__defineClass = require("$fp$runtime__defineClass");
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
  
}/* class decorators */
let C3 = $fp$runtime__defineClass(class C3 {
    
  }, [], [c => c, dec], []);
/* method decorators */
let C4 = $fp$runtime__defineClass(class C4 {
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
let C5 = $fp$runtime__defineClass(class  {
    constructor( ...args) {
      Object.defineProperty(this, "prop1", {"configurable": true, "enumerable": true, "writable": true, "value": void 0});
      
    }
    
  }, [{"name": "prop2", "value": void 0}], [], []);
/* all of the above */
let C6 = $fp$runtime__defineClass(class C6 extends C5 {
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
