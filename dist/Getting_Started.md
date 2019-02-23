# Getting Started

## Install

You can install fastpack either globally or as a development dependency.

As a global dependency:

```shell
$ npm i -g fastpack
$ yarn global add fastpack
```

As a development dependency:

```shell
$ npm i --save-dev fastpack
$ yarn add --dev fastpack
```

## CLI

### Create Bundle

To learn the basics of fastpacks CLI interface let's create a simple project.

Create a folder on your computer, then from the command line initialize it:

```shell
$ yarn init -y && yarn add --dev fastpack
```

Now you have the faspack module as a development dependency. Next create an index.js file and add the following:

```
const name = "fastpack"

const hearMeRoar = name.split("").join("👏");

console.log(hearMeRoar);
```

Let's bundle this from the command line:

```bash
$ npx fpack --dev index.js
```

> If you installed fastpack globally you don't need `npx` right before

Voila! You should now see in your project `bundle/index.js`

### Watch for Changes

In most cases you will not want to run this command all the time, instead you will want fastpack to wacth for changes and build a new bundle accordingly. Use the `watch` command for this.

```shell
$ npx fpack watch --dev index.js
```

Next, make a change to the `index.js` file. Afterward you should see updates in terminal.

### Output to Folder with Filename

Let's try to output the bundle to a new folder with an updated filename. For this you will need the `-o` and `-n` options.

```shell
$ npx fpack watch --dev index.js -o ./dist -n module.js
```

### Target a Node Environment

You may want to target a node environment instead of the browser. For this you use the `--target` option.

```shell
$ npx fpack watch --dev index.js -o ./dist -n module.js --target cjm
```

### No Caching

You may not what to cache for a clean build. Use the `--no-cache` option for this.

```shell
$ npx fpack watch --dev index.js -o ./dist -n module.js --target cjm ---no-cache
```
