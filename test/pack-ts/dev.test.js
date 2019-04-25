module.exports = ({bundle}) => bundle(`
fpack build index.ts --dev --preprocess=\\.ts$:ts-loader
`);
