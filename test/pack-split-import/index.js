import * as a from "./a";

import("./a").then(m => {
  console.log('statically imported ./a:', a);
  console.log('dynamically imported ./a:', m);

  import("./b").then(m => {
    console.log('dynamically imported ./b:', m);
  })

  import("./c").then(m => {
    console.log('dynamically imported ./c:', m);
  })
})
