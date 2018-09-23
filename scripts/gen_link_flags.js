switch(process.platform) {
  case "linux":
    console.log("(-ccopt -static)");
    break;
  default:
    console.log("(-ccopt -L/usr/lib)");
}
