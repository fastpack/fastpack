
let p;

// if-then-no-else
if (process.env.NODE_ENV == "production")
  p = require("./prod");

if (process.env.NODE_ENV === "production")
  p = require("./prod");

if (process.env.NODE_ENV != "development")
  p = require("./prod");

if (process.env.NODE_ENV !== "development")
  p = require("./prod");

if (process.env.NODE_ENV == "development")
  p = require("./dev");

if (process.env.NODE_ENV === "development")
  p = require("./dev");

if (process.env.NODE_ENV != "production")
  p = require("./dev");

if (process.env.NODE_ENV !== "production")
  p = require("./dev");

// if-then-else
if (process.env.NODE_ENV == "production")
  p = require("./prod");
else
  p = require("./dev");

if (process.env.NODE_ENV === "production")
  p = require("./prod");
else
  p = require("./dev");

if (process.env.NODE_ENV != "development")
  p = require("./prod");
else
  p = require("./dev");

if (process.env.NODE_ENV !== "development")
  p = require("./prod");
else
  p = require("./dev");

if (process.env.NODE_ENV == "development")
  p = require("./dev");
else
  p = require("./prod");

if (process.env.NODE_ENV === "development")
  p = require("./dev");
else
  p = require("./prod");

if (process.env.NODE_ENV != "production")
  p = require("./dev");
else
  p = require("./prod");

if (process.env.NODE_ENV !== "production")
  p = require("./dev");
else
  p = require("./prod");


// alternative statement
if ("production" == process.env.NODE_ENV)
  p = require("./prod");
else
  p = require("./dev");

// logical AND expression
if (process.env.NODE_ENV == "production" && x && y && z)
  p = require("./prod");
else
  p = require("./dev");

// conditional operator
p = process.env.NODE_ENV == "production" ? require("./prod") : require("./dev");
console.log(process.env.NODE_ENV);

// bug
if (true) {} else if (process.env.NODE_ENV == "production") {console.log("prod!")}
if (false) {} else if (process.env.NODE_ENV == "development") {console.log("dev!")}

// bug
Image.propTypes = process.env.NODE_ENV !== "production" ? call() : ({});
