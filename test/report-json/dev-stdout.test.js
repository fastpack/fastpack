module.exports = ({fpack, result}) => {
  let {stdout} = fpack("fpack index.js --dev --report=json");
  result(stdout.replace(/0\.\d+/, "0.005"));
}
