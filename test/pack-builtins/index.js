const esm = require('./esm');

const {delimiter, ...rest} = path;

console.log(path, module, delimiter, rest, esm);

// The following test makes sure that builtin transpiler strips type annotations
// from inside JSX
const Component = props => (
  <div>
    {(item: string) => {}}
  </div>
);
