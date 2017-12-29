import {a1, a2} from './a';
import {d1, d2} from './d';

{
  {
    import('./e');
  }
}


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
