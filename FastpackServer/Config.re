type rewrite = {
  pattern_s: string,
  pattern: Re.re,
  target: string,
};

type t = {
  port: int,
  outputDir: string,
  rewrite: list(rewrite),
  debug: bool,
};
