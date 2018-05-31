
import C from './C';
import {inherit} from './Util';

var Q = (function() {
  var Q = { className: 'Q'};
  inherit(Q, C);
  return Q;
})();

export default Q;
