const http = require("http");
const path = require("path");
const fs = require("fs");

const reBuild = /^build/;
function findBundles() {
  return fs.readdirSync(".").reduce((acc, file) => {
    let absPath = path.join("./", file);
    if (file !== "node_modules" && fs.statSync(absPath).isDirectory()) {
      return fs.readdirSync(absPath).reduce((acc, file) => {
        let buildPath = path.join(absPath, file);
        if (
          !fs.statSync(buildPath) ||
          file == "node_modules" ||
          file == "src" ||
          file.substr(0, 1) == "_" ||
          !fs.existsSync(path.join(buildPath, "index.js"))
        ) {
          return acc;
        } else {
          return [].concat(acc, [buildPath]);
        }
      }, acc);
    } else {
      return acc;
    }
  }, []);
}

function mainIndex() {
  let bundles = findBundles(".");
  bundles.sort();
  let links = bundles.map(b => `<a href="${b}/">${b}</a>`).join("<br/>");
  return `
<!DOCTYPE html>
<html>
<head><title>All Builds</title></head>
<body>${links}</body>
</html>
  `;
}

function buildIndex() {
  return `
<!DOCTYPE html>
<html>
<head><title>All Builds</title></head>
<body>
<div id="root"></div>
<script type="text/javascript" src="./index.js"></script>
</body>
</html>
  `;
}

http
  .createServer(function(request, response) {
    console.log(request.url);

    var filePath = "." + request.url;
    if (filePath == "./") {
      response.writeHead(200, { "Content-Type": "text/html" });
      response.end(mainIndex(), "utf-8");
      return;
    }

    if (fs.existsSync(path.join(filePath, "index.js"))) {
      response.writeHead(200, { "Content-Type": "text/html" });
      response.end(buildIndex(), "utf-8");
      return;
    }

    var extname = String(path.extname(filePath)).toLowerCase();
    var contentType = "text/html";
    var mimeTypes = {
      ".html": "text/html",
      ".js": "text/javascript",
      ".css": "text/css",
      ".json": "application/json",
      ".png": "image/png",
      ".jpg": "image/jpg",
      ".gif": "image/gif",
      ".wav": "audio/wav",
      ".mp4": "video/mp4",
      ".woff": "application/font-woff",
      ".ttf": "application/font-ttf",
      ".eot": "application/vnd.ms-fontobject",
      ".otf": "application/font-otf",
      ".svg": "image/svg+xml"
    };

    contentType = mimeTypes[extname] || "application/octet-stream";

    fs.readFile(filePath, function(error, content) {
      if (error) {
        if (error.code == "ENOENT") {
          response.writeHead(404);
          response.end(filePath + " not found\n");
        } else {
          response.writeHead(500);
          response.end(
            "Sorry, check with the site admin for error: " +
              error.code +
              " ..\n"
          );
          response.end();
        }
      } else {
        response.writeHead(200, { "Content-Type": contentType });
        response.end(content, "utf-8");
      }
    });
  })
  .listen(4321);
console.log("Server running at http://127.0.0.1:4321/");
