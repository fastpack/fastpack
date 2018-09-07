let executable = ref(Sys.argv[0]);

let getExecutable = () => executable^;
let setExecutable = newExecutable => executable := newExecutable;
