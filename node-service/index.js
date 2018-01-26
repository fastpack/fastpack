function handleError(e) {
  var message = e.message || e + "";
  var name = e.name || "UnknownError";
  var stack = e.stack || null;
  return { name: name, message: message + "--" + process.cwd(), stack: stack };
}

function load(module, params, source) {
  var ret = { dependencies: [], source: null, error: null };

  var loaderContext = {
    loaders: [],

    query: params || {},

    addDependency(file) {
      // TODO: abs path
      ret.dependencies.push(file);
    },

    callback(error, code, map) {
      if (error) {
        ret.error = handleError(error);
      } else {
        ret.source = code;
      }
    }
  };

  try {
    var loader = require(module);
    loader.call(loaderContext, source);
  } catch (e) {
    ret.error = handleError(e);
  }
  return ret;
}

var stdin = process.stdin,
  stdout = process.stdout,
  rest = "";

function write(obj) {
  var message = JSON.stringify(obj);
  stdout.write(message + "\n");
}

stdin.resume();
stdin.setEncoding("utf8");

stdin.on("data", function(data) {
  var nl = data.indexOf("\n");
  if (nl === -1) {
    rest += data;
  } else {
    var message = rest + data.slice(0, nl);
    rest = data.slice(nl + 1);
    try {
      message = JSON.parse(message);
      var loader = message.loader;
      if (!loader)
        throw { name: "ErrorNoLoader", message: '"loader" is not specified' };
      var params = message.params || {};
      if (!(params instanceof Object) || params instanceof Array)
        throw {
          name: "ErrorInvalidParams",
          message: '"params" should be plain object'
        };
      var source = message.source;
      if (typeof source !== "string")
        throw {
          name: "ErrorInvalidSource",
          message: '"source" expected to be string'
        };
      var result = load(loader, params, source);
      write(result);
    } catch (e) {
      write({ error: handleError(e), source: null, dependencies: [] });
    }
  }
});

function loop() {
  setImmediate(loop);
}
loop();
