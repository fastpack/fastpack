module.exports = ({ error }) =>
  error(
    `
fpack build index.js --dev
`,
    { env: { FPACK_FORCE_TTY: "true" } }
  );
