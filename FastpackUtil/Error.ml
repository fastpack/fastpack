
exception UnhandledCondition of string
let ie s = raise (UnhandledCondition s)
