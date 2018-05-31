
import QC from './QC';
import {inherit} from './Util';

var C = (function() {
  var C = { className: 'C'};
  inherit(C, QC);
  return C;
})();

export default C;
