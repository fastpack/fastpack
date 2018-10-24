module.exports = ({bundle}) => bundle(`
fpack index.ts --dev --preprocess='\\.ts$:ts-loader'
`);
