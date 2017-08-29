/* nothing to transform */

class CC {
  method1() {}
  constructor() {}
  method2() {}
}

/* no costructor */
class C {
  state = 1;
}

/* with constructor */
class C1 {
  x = 1;
  y = 2;

  constructor() {
    this.z = this.x + this.y;
  }
}


/* with constructor & super */
class C2 extends C1 {

  method() {}
  constructor() {
    debugger;
    super();
    this.onClick();
  }

  onClick = (e) => {console.log('hello');}
  onMouseMove = (e) => {console.log(e);}
  doSomethingUseful = () => 42;
}
