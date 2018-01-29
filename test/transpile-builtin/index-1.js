// @flow

// The following test makes sure that builtin transpiler strips type annotations
// from inside JSX
const Component = props => (
  <div>
    {(item: string) => {}}
  </div>
);
