@cls
@(cls => cls)
class C6 extends C5 {

  prop_no_value;
  prop_int = 1;
  prop_func = x => x + 1;

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
