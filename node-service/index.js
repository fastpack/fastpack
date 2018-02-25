var path = require("path");
var fs = require("fs");
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
  var ret = { files: [], dependencies: [], source: null, error: null };
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
    var files = [];
    var runner = require("loader-runner");
    runner.runLoaders(
      {
        resource: filename,
        loaders: loaders,
        context: {
          _compiler: {
            plugin: function() {}
          },
          _module: {
            errors: [],
            meta: {}
          },
          resolve: function(context, request, callback) {
            var request =
              request[0] == "." ? "./" + path.join(context, request) : request;
            try {
              callback(null, require.resolve(request));
            } catch(e) {
              callback(e, null);
            }
          },
          options: {},
          emitFile: function(name, buffer) {
            files.push({
              name: name,
              content: buffer
            });
          }
        },
        readResource: function(path, callback) {
          if (path === filename && source) {
            callback(null, Buffer.from(source, "utf-8"));
          } else {
            return fs.readFile(path, callback);
          }
        }
      },
      function(error, result) {
        if (error) {
          ret.error = handleError(error);
        } else if (result.result instanceof Array) {
          ret.source = extractSource(result.result);
          if (ret.source !== null) {
            ret.dependencies = [].concat(
              result.fileDependencies || [],
              result.contextDependencies || []
            );
          } else {
            ret.error = {
              name: "UnexpectedResult",
              message:
                "Cannot extract result from loader. " +
                "Expected results: Array of String, Buffer, String"
            };
          }
        }
        for (var i = 0, l = files.length; i < l; i++) {
          var absPath = path.join(outputDir, files[i].name);
          writeFile(absPath, files[i].content);
          ret.files.push(absPath);
        }
        write(ret);
      }
    );
  } catch (e) {
    ret.error = handleError(e);
    write(ret);
  }
}

var outputDir = process.argv[2],
  stdin = process.stdin,
  rest = "";

var writeOrig = process.stdout.write.bind(process.stdout);
process.stdout.write = function() {};
process.stderr.write = function() {};
function write(obj) {
  var message = JSON.stringify(obj);
  writeOrig(message + "\n");
}

function makeDirs(dir) {
  if (fs.existsSync(dir)) {
    return;
  }
  makeDirs(path.dirname(dir));
  fs.mkdirSync(dir);
}

function writeFile(absPath, content) {
  if (absPath.substr(0, outputDir.length) !== outputDir) {
    throw {
      name: "FileWriteError",
      message: "Path is out of the output directory: " + absPath
    };
  }
  makeDirs(path.dirname(absPath));
  fs.writeFileSync(absPath, content);
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

// require('net').createServer().listen();
