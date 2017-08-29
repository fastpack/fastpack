/* nothing to transform */
class CC {
  method1() {
    
  }
  constructor() {
    
  }
  method2() {
    
  }
};
/* no costructor */
class C {
  constructor() {
    Object.defineProperty(this, "state", {"configurable": true, "enumerable": true, "writable": true, "value": 1})
  }
};
/* with constructor */
class C1 {
  constructor() {
    Object.defineProperty(this, "x", {"configurable": true, "enumerable": true, "writable": true, "value": 1});
    Object.defineProperty(this, "y", {"configurable": true, "enumerable": true, "writable": true, "value": 2});
    this.z = this.x + this.y
  }
};
/* with constructor & super */
class C2 extends C1 {
  method() {
    
  }
  constructor() {
    debugger;
    super();
    Object.defineProperty(this, "onClick", {"configurable": true, "enumerable": true, "writable": true, "value": (e) =>  {
      console.log('hello')
    }});
    Object.defineProperty(this, "onMouseMove", {"configurable": true, "enumerable": true, "writable": true, "value": (e) =>  {
      console.log(e)
    }});
    Object.defineProperty(this, "doSomethingUseful", {"configurable": true, "enumerable": true, "writable": true, "value": () =>  (42)});
    this.onClick()
  }
};
