exception UnhandledCondition(string);
let ie = s => raise(UnhandledCondition(s));
