const path = require("path");
module.paths.unshift(path.join(process.cwd(), "node_modules"));

function handleError(e) {
  var message = e.message || e + "";
  var name = e.name || "UnknownError";
  var stack = e.stack || null;
  return { name: name, message: message, stack: stack };
}

function extractSource(result) {
  if (result instanceof Array) {
    return extractSource(result[0]);
  } else if (result instanceof Buffer) {
    return Buffer.from(result, "utf-8");
  } else if (typeof result === "string") {
    return result;
  } else {
    return null;
  }
}

function load(message) {
  var ret = { dependencies: [], source: null, error: null };
  try {
    var message = JSON.parse(message);
  } catch (e) {
    ret.error = handleError(e);
    write(ret);
    return;
  }

  var loaders = message.loaders || [];
  var filename = message.filename || null;
  var source = message.source || null;

  try {
    // TODO: mock stdout / stderr
    var runner = require("loader-runner");
    runner.runLoaders(
      {
        resource: filename,
        loaders: loaders,
        context: {},
        readResource: function(path, callback) {
          if (path === filename) {
            callback(null, Buffer.from(source, "utf-8"));
          } else {
            return fs.readFile(path, callback);
          }
        }
      },
      function(err, result) {
        // TODO: Unmock stdout / stderr
        if (err) {
          ret.err = handleError(err);
        } else if (result.result instanceof Array) {
          ret.source = extractSource(result.result);
          if (ret.source !== null) {
            ret.dependencies = [].concat(
              result.fileDependencies || [],
              result.contextDependencies || []
            );
          } else {
            ret.err = {
              name: "UnexpectedResult",
              message:
                "Cannot extract result from loader. "
                + "Expected results: Array of String, Buffer, String"
            };
          }
        }
        write(ret);
      }
    );
  } catch (e) {
    // TODO: Unmock stdout/stderr here
    ret.error = handleError(e);
    write(ret);
  }
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
    load(message);
  }
});

function loop() {
  setImmediate(loop);
}
loop();
