# Fastpack

[![Build Status](https://dev.azure.com/fastpack/fastpack/_apis/build/status/fastpack.fastpack)](https://dev.azure.com/fastpack/fastpack/_build/latest?definitionId=1)
[![Backers on Open Collective](https://opencollective.com/fastpack/backers/badge.svg)](#backers)
 [![Sponsors on Open Collective](https://opencollective.com/fastpack/sponsors/badge.svg)](#sponsors)

Pack JS code into a single bundle fast & easy.

## Why?

Because JavaScript builds should be faster!

Here is an example benchmark of bundling ~1600 modules together.


|   | Fastpack| Parcel| Webpack
|----|:--:|:--:|:--:
| initial build| **0.730s**| 9.740s| 3.625s
| persistent cache| **0.171s**| 1.218s| N/A
| watch mode| **0.084s**| 0.503s| 0.473s

## Getting Started

Let's try building a simple React application!

```Bash
  $ mkdir react-app
  $ cd react-app
  $ yarn init -y
  $ yarn add react react-dom
  $ yarn add --dev fastpack
  $ yarn add --dev babel-loader babel-preset-react-app style-loader css-loader url-loader
```

**src/index.js**
```JavaScript
import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import App from './App';

ReactDOM.render(<App />, document.getElementById('root'));
```

**src/index.css**
```CSS
body {
  margin: 0;
  padding: 0;
  font-family: sans-serif;
}
```

**src/App.js**
```JavaScript
import React, { Component } from 'react';
import logo from './logo.svg';
import './App.css';

class App extends Component {
  render() {
    return (
      <div className="App">
        <header className="App-header">
          <img src={logo} className="App-logo" alt="logo" />
          <h1 className="App-title">Welcome to React</h1>
        </header>
        <p className="App-intro">
          To get started, edit <code>src/App.js</code> and save to reload.
        </p>
      </div>
    );
  }
}

export default App;
```

**src/App.css**
```CSS
.App {
  text-align: center;
}

.App-logo {
  animation: App-logo-spin infinite 20s linear;
  height: 80px;
}

.App-header {
  background-color: #222;
  height: 150px;
  padding: 20px;
  color: white;
}

.App-title {
  font-size: 1.5em;
}

.App-intro {
  font-size: large;
}

@keyframes App-logo-spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
```

**index.html**
```HTML
<!DOCTYPE html>
<html>
<head><title>React App</title></head>
<body>
<div id="root"></div>
<script type="text/javascript" src="./bundle/index.js"></script>
</body>
</html>
```

Also, add the `src/logo.svg` of your choice. Now let's add some config:

**.babelrc**
```JavaScript
{
    "presets": ["react-app"]
}
```

And the fastpack configuration as well:

**fastpack.json**
```JavaScript
{
    "entryPoints": ["src/index.js"],
    "preprocess": [
        {
            "re": "^src.+\\.js$",
            "process": "babel-loader"
        },
        {
            "re": "\\.svg$",
            "process": "url-loader"
        },
        {
            "re": "\\.css$",
            "process": "style-loader!css-loader"
        }
    ]
}
```

*The above configuration can be alternatively specified using command-line
arguments, for more details run:*

```Bash
  $ node_modules/.bin/fpack --help
```

We are good to go! Now run:

```Bash
  $ node_modules/.bin/fpack build --dev
  Cache: empty
  Done in 0.817s. Bundle: 942Kb. Modules: 30.
  $ open index.html
```

Voila! Now try running it again and see the power of the persistent cache!

```Bash
  $ node_modules/.bin/fpack build --dev
  Cache: used
  Done in 0.032s. Bundle: 942Kb. Modules: 30.
```

For more configuration options and usage scenarios see
[Documentation](https://fastpack.sh/docs/get-started.html).

Have a question or want to contribute? Join us on [Discord](https://discord.gg/4HVCjDh)!

## Contributors

This project exists thanks to all the people who contribute.
<a href="https://github.com/fastpack/fastpack/graphs/contributors"><img src="https://opencollective.com/fastpack/contributors.svg?width=890&button=false" /></a>

Special thanks to [@camsong](https://github.com/camsong) for providing the
[fastpack](https://www.npmjs.com/package/fastpack) name on
[npmjs.com](npmjs.com)!


## Backers

Thank you to all our backers! 🙏 [[Become a backer](https://opencollective.com/fastpack#backer)]

<a href="https://opencollective.com/fastpack#backers" target="_blank"><img src="https://opencollective.com/fastpack/backers.svg?width=890"></a>


## Sponsors

Support this project by becoming a sponsor. Your logo will show up here with a link to your website. [[Become a sponsor](https://opencollective.com/fastpack#sponsor)]

<a href="https://opencollective.com/fastpack/sponsor/0/website" target="_blank"><img src="https://opencollective.com/fastpack/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/fastpack/sponsor/1/website" target="_blank"><img src="https://opencollective.com/fastpack/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/fastpack/sponsor/2/website" target="_blank"><img src="https://opencollective.com/fastpack/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/fastpack/sponsor/3/website" target="_blank"><img src="https://opencollective.com/fastpack/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/fastpack/sponsor/4/website" target="_blank"><img src="https://opencollective.com/fastpack/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/fastpack/sponsor/5/website" target="_blank"><img src="https://opencollective.com/fastpack/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/fastpack/sponsor/6/website" target="_blank"><img src="https://opencollective.com/fastpack/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/fastpack/sponsor/7/website" target="_blank"><img src="https://opencollective.com/fastpack/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/fastpack/sponsor/8/website" target="_blank"><img src="https://opencollective.com/fastpack/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/fastpack/sponsor/9/website" target="_blank"><img src="https://opencollective.com/fastpack/sponsor/9/avatar.svg"></a>


