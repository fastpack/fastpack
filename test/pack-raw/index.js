import text from 'raw-loader!./test.txt';

document.body.innerHTML = `
<h1>test.txt</h1>
<pre>${text}</pre>
`;
