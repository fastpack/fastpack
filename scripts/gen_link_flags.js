switch(process.platform) {
  case "linux":
    console.log("(-ccopt -static)");
  default:
    console.log("()");
}
