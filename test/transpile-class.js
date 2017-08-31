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

/* constructor */
class C1 {
  x = 1;
  y = 2;

  constructor() {
    this.z = this.x + this.y;
  }
}


/* constructor & super */
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

/* class decorators */
@(c => c)
@dec
class C3 {

}

/* method decorators */
class C4 {

  @(dec)
  method1() {}

  @(m => m)
  @dec2
  method2() {}
}

/* class expressions */
(class {
  prop1;
});

let C5 = class {
  prop1;
  static prop2;
};

/* all of the above */

@cls
@(cls => cls)
class C6 extends C5 {

  prop_no_value;
  prop_int = 1;
  prop_func = x => x + 1;
  static static_prop;

  method1() {}

  @(m => m)
  methodDecorated2() {}

  constructor() {
    before_super1();
    before_super2();
    super();
    after_super_and_props();
  }

  @mDec1
  @mDec2
  methodDecorated3() {}
}
