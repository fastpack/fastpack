// @flow

import './transpile-class.js'
import './transpile-object-spread.js'
// import './transpile-optional-chaining.js'
import './transpile-react-jsx.js'
import './transpile-strip-flow.js'

// The following test makes sure that builtin transpiler strips type annotations
// from inside JSX
const Component = props => (
  <div>
    {(item: string) => {}}
  </div>
);
