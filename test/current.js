/* class decorators */
@(f => f)
@(function decorator1(s) {
  return s
})
@decorator2
class C {}
