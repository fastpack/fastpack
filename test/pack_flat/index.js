import {a1, a2 as A2} from './a';
import * as D from './d';
import Declaration from './default_declaration';

{
  {
    import('./e');
  }
}
console.log(A2, D, Declaration, Expression);


/*
 * Legend
 *   (=>) : requires statically
 *   (->) : requires dynamically
 * Dependencies:
 *   index => a
 *   index => d
 *   index => e
 *   d => a
 *   d -> c
 *   c -> b
 *   b => a
 */
