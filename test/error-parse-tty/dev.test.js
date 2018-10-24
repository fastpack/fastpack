module.exports = ({ error }) =>
  error(
    `
fpack index.js --dev
`,
    { env: { FPACK_FORCE_TTY: "true" } }
  );
