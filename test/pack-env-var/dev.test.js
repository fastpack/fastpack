module.exports = ({ bundle }) =>
  bundle(
    `
fpack --dev --env-var=API_URL --env-var=SECRET=hello index.js
`,
    { env: { API_URL: "https://example.com", API: "should not be included" } }
  );
