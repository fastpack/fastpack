(function() {

/* NM$$css$$_$$loader$lib$css$$_$$base */

let $n__NM$$css$$_$$loader$lib$css$$_$$base = { id: "NM$$css$$_$$loader$lib$css$$_$$base", exports: {}};
/*
	MIT License http://www.opensource.org/licenses/mit-license.php
	Author Tobias Koppers @sokra
*/
// css base code, injected by the css-loader
$n__NM$$css$$_$$loader$lib$css$$_$$base.exports = function(useSourceMap) {
	var list = [];

	// return the list of modules as css string
	list.toString = function toString() {
		return this.map(function (item) {
			var content = $i__NM$$css$$_$$loader$lib$css$$_$$base__cssWithMappingToString(item, useSourceMap);
			if(item[2]) {
				return "@media " + item[2] + "{" + content + "}";
			} else {
				return content;
			}
		}).join("");
	};

	// import a list of modules into the list
	list.i = function(modules, mediaQuery) {
		if(typeof modules === "string")
			modules = [[null, modules, ""]];
		var alreadyImportedModules = {};
		for(var i = 0; i < this.length; i++) {
			var id = this[i][0];
			if(typeof id === "number")
				alreadyImportedModules[id] = true;
		}
		for(i = 0; i < modules.length; i++) {
			var item = modules[i];
			// skip already imported module
			// this implementation is not 100% perfect for weird media query combinations
			//  when a module is imported multiple times with different media queries.
			//  I hope this will never occur (Hey this way we have smaller bundles)
			if(typeof item[0] !== "number" || !alreadyImportedModules[item[0]]) {
				if(mediaQuery && !item[2]) {
					item[2] = mediaQuery;
				} else if(mediaQuery) {
					item[2] = "(" + item[2] + ") and (" + mediaQuery + ")";
				}
				list.push(item);
			}
		}
	};
	return list;
};

function $i__NM$$css$$_$$loader$lib$css$$_$$base__cssWithMappingToString(item, useSourceMap) {
	var content = item[1] || '';
	var cssMapping = item[3];
	if (!cssMapping) {
		return content;
	}

	if (useSourceMap && typeof btoa === 'function') {
		var sourceMapping = $i__NM$$css$$_$$loader$lib$css$$_$$base__toComment(cssMapping);
		var sourceURLs = cssMapping.sources.map(function (source) {
			return '/*# sourceURL=' + cssMapping.sourceRoot + source + ' */'
		});

		return [content].concat(sourceURLs).concat([sourceMapping]).join('\n');
	}

	return [content].join('\n');
}

// Adapted from convert-source-map (MIT)
function $i__NM$$css$$_$$loader$lib$css$$_$$base__toComment(sourceMap) {
	// eslint-disable-next-line no-undef
	var base64 = btoa(unescape(encodeURIComponent(JSON.stringify(sourceMap))));
	var data = 'sourceMappingURL=data:application/json;charset=utf-8;base64,' + base64;

	return '/*# ' + data + ' */';
}

try{$n__NM$$css$$_$$loader$lib$css$$_$$base.exports.__esModule = $n__NM$$css$$_$$loader$lib$css$$_$$base.exports.__esModule || false;}catch(_){}

/* NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css */

let $n__NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css = { id: "NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css", exports: {}};
exports = $n__NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.exports = ($n__NM$$css$$_$$loader$lib$css$$_$$base.exports)(false);
// imports


// module
$n__NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.exports.push([$n__NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.id, "body { color: red; }\n.x { color: blue; }\n", ""]);

// exports

try{$n__NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.exports.__esModule = $n__NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.exports.__esModule || false;}catch(_){}

/* NM$$style$$_$$loader$lib$urls */

let $n__NM$$style$$_$$loader$lib$urls = { id: "NM$$style$$_$$loader$lib$urls", exports: {}};

/**
 * When source maps are enabled, `style-loader` uses a link element with a data-uri to
 * embed the css on the page. This breaks all relative urls because now they are relative to a
 * bundle instead of the current page.
 *
 * One solution is to only use full urls, but that may be impossible.
 *
 * Instead, this function "fixes" the relative urls to be absolute according to the current page location.
 *
 * A rudimentary test suite is located at `test/fixUrls.js` and can be run via the `npm test` command.
 *
 */

$n__NM$$style$$_$$loader$lib$urls.exports = function (css) {
  // get current location
  var location = typeof window !== "undefined" && window.location;

  if (!location) {
    throw new Error("fixUrls requires window.location");
  }

	// blank or null?
	if (!css || typeof css !== "string") {
	  return css;
  }

  var baseUrl = location.protocol + "//" + location.host;
  var currentDir = baseUrl + location.pathname.replace(/\/[^\/]*$/, "/");

	// convert each url(...)
	/*
	This regular expression is just a way to recursively match brackets within
	a string.

	 /url\s*\(  = Match on the word "url" with any whitespace after it and then a parens
	   (  = Start a capturing group
	     (?:  = Start a non-capturing group
	         [^)(]  = Match anything that isn't a parentheses
	         |  = OR
	         \(  = Match a start parentheses
	             (?:  = Start another non-capturing groups
	                 [^)(]+  = Match anything that isn't a parentheses
	                 |  = OR
	                 \(  = Match a start parentheses
	                     [^)(]*  = Match anything that isn't a parentheses
	                 \)  = Match a end parentheses
	             )  = End Group
              *\) = Match anything and then a close parens
          )  = Close non-capturing group
          *  = Match anything
       )  = Close capturing group
	 \)  = Match a close parens

	 /gi  = Get all matches, not the first.  Be case insensitive.
	 */
	var fixedCss = css.replace(/url\s*\(((?:[^)(]|\((?:[^)(]+|\([^)(]*\))*\))*)\)/gi, function(fullMatch, origUrl) {
		// strip quotes (if they exist)
		var unquotedOrigUrl = origUrl
			.trim()
			.replace(/^"(.*)"$/, function(o, $1){ return $1; })
			.replace(/^'(.*)'$/, function(o, $1){ return $1; });

		// already a full url? no change
		if (/^(#|data:|http:\/\/|https:\/\/|file:\/\/\/)/i.test(unquotedOrigUrl)) {
		  return fullMatch;
		}

		// convert the url to a full url
		var newUrl;

		if (unquotedOrigUrl.indexOf("//") === 0) {
		  	//TODO: should we add protocol?
			newUrl = unquotedOrigUrl;
		} else if (unquotedOrigUrl.indexOf("/") === 0) {
			// path should be relative to the base url
			newUrl = baseUrl + unquotedOrigUrl; // already starts with '/'
		} else {
			// path should be relative to current directory
			newUrl = currentDir + unquotedOrigUrl.replace(/^\.\//, ""); // Strip leading './'
		}

		// send back the fixed url(...)
		return "url(" + JSON.stringify(newUrl) + ")";
	});

	// send back the fixed css
	return fixedCss;
};

try{$n__NM$$style$$_$$loader$lib$urls.exports.__esModule = $n__NM$$style$$_$$loader$lib$urls.exports.__esModule || false;}catch(_){}

/* NM$$style$$_$$loader$lib$addStyles */

let $n__NM$$style$$_$$loader$lib$addStyles = { id: "NM$$style$$_$$loader$lib$addStyles", exports: {}};
/*
	MIT License http://www.opensource.org/licenses/mit-license.php
	Author Tobias Koppers @sokra
*/

var $i__NM$$style$$_$$loader$lib$addStyles__stylesInDom = {};

var	$i__NM$$style$$_$$loader$lib$addStyles__memoize = function (fn) {
	var memo;

	return function () {
		if (typeof memo === "undefined") memo = fn.apply(this, arguments);
		return memo;
	};
};

var $i__NM$$style$$_$$loader$lib$addStyles__isOldIE = $i__NM$$style$$_$$loader$lib$addStyles__memoize(function () {
	// Test for IE <= 9 as proposed by Browserhacks
	// @see http://browserhacks.com/#hack-e71d8692f65334173fee715c222cb805
	// Tests for existence of standard globals is to allow style-loader
	// to operate correctly into non-standard environments
	// @see https://github.com/webpack-contrib/style-loader/issues/177
	return window && document && document.all && !window.atob;
});

var $i__NM$$style$$_$$loader$lib$addStyles__getTarget = function (target) {
  return document.querySelector(target);
};

var $i__NM$$style$$_$$loader$lib$addStyles__getElement = (function (fn) {
	var memo = {};

	return function(target) {
                // If passing function in options, then use it for resolve "head" element.
                // Useful for Shadow Root style i.e
                // {
                //   insertInto: function () { return document.querySelector("#foo").shadowRoot }
                // }
                if (typeof target === 'function') {
                        return target();
                }
                if (typeof memo[target] === "undefined") {
			var styleTarget = $i__NM$$style$$_$$loader$lib$addStyles__getTarget.call(this, target);
			// Special case to return head of iframe instead of iframe itself
			if (window.HTMLIFrameElement && styleTarget instanceof window.HTMLIFrameElement) {
				try {
					// This will throw an exception if access to iframe is blocked
					// due to cross-origin restrictions
					styleTarget = styleTarget.contentDocument.head;
				} catch(e) {
					styleTarget = null;
				}
			}
			memo[target] = styleTarget;
		}
		return memo[target]
	};
})();

var $i__NM$$style$$_$$loader$lib$addStyles__singleton = null;
var	$i__NM$$style$$_$$loader$lib$addStyles__singletonCounter = 0;
var	$i__NM$$style$$_$$loader$lib$addStyles__stylesInsertedAtTop = [];

var	$i__NM$$style$$_$$loader$lib$addStyles__fixUrls = ($n__NM$$style$$_$$loader$lib$urls.exports);

$n__NM$$style$$_$$loader$lib$addStyles.exports = function(list, options) {
	if (typeof DEBUG !== "undefined" && DEBUG) {
		if (typeof document !== "object") throw new Error("The style-loader cannot be used in a non-browser environment");
	}

	options = options || {};

	options.attrs = typeof options.attrs === "object" ? options.attrs : {};

	// Force single-tag solution on IE6-9, which has a hard limit on the # of <style>
	// tags it will allow on a page
	if (!options.singleton && typeof options.singleton !== "boolean") options.singleton = $i__NM$$style$$_$$loader$lib$addStyles__isOldIE();

	// By default, add <style> tags to the <head> element
        if (!options.insertInto) options.insertInto = "head";

	// By default, add <style> tags to the bottom of the target
	if (!options.insertAt) options.insertAt = "bottom";

	var styles = $i__NM$$style$$_$$loader$lib$addStyles__listToStyles(list, options);

	$i__NM$$style$$_$$loader$lib$addStyles__addStylesToDom(styles, options);

	return function update (newList) {
		var mayRemove = [];

		for (var i = 0; i < styles.length; i++) {
			var item = styles[i];
			var domStyle = $i__NM$$style$$_$$loader$lib$addStyles__stylesInDom[item.id];

			domStyle.refs--;
			mayRemove.push(domStyle);
		}

		if(newList) {
			var newStyles = $i__NM$$style$$_$$loader$lib$addStyles__listToStyles(newList, options);
			$i__NM$$style$$_$$loader$lib$addStyles__addStylesToDom(newStyles, options);
		}

		for (var i = 0; i < mayRemove.length; i++) {
			var domStyle = mayRemove[i];

			if(domStyle.refs === 0) {
				for (var j = 0; j < domStyle.parts.length; j++) domStyle.parts[j]();

				delete $i__NM$$style$$_$$loader$lib$addStyles__stylesInDom[domStyle.id];
			}
		}
	};
};

function $i__NM$$style$$_$$loader$lib$addStyles__addStylesToDom (styles, options) {
	for (var i = 0; i < styles.length; i++) {
		var item = styles[i];
		var domStyle = $i__NM$$style$$_$$loader$lib$addStyles__stylesInDom[item.id];

		if(domStyle) {
			domStyle.refs++;

			for(var j = 0; j < domStyle.parts.length; j++) {
				domStyle.parts[j](item.parts[j]);
			}

			for(; j < item.parts.length; j++) {
				domStyle.parts.push($i__NM$$style$$_$$loader$lib$addStyles__addStyle(item.parts[j], options));
			}
		} else {
			var parts = [];

			for(var j = 0; j < item.parts.length; j++) {
				parts.push($i__NM$$style$$_$$loader$lib$addStyles__addStyle(item.parts[j], options));
			}

			$i__NM$$style$$_$$loader$lib$addStyles__stylesInDom[item.id] = {id: item.id, refs: 1, parts: parts};
		}
	}
}

function $i__NM$$style$$_$$loader$lib$addStyles__listToStyles (list, options) {
	var styles = [];
	var newStyles = {};

	for (var i = 0; i < list.length; i++) {
		var item = list[i];
		var id = options.base ? item[0] + options.base : item[0];
		var css = item[1];
		var media = item[2];
		var sourceMap = item[3];
		var part = {css: css, media: media, sourceMap: sourceMap};

		if(!newStyles[id]) styles.push(newStyles[id] = {id: id, parts: [part]});
		else newStyles[id].parts.push(part);
	}

	return styles;
}

function $i__NM$$style$$_$$loader$lib$addStyles__insertStyleElement (options, style) {
	var target = $i__NM$$style$$_$$loader$lib$addStyles__getElement(options.insertInto)

	if (!target) {
		throw new Error("Couldn't find a style target. This probably means that the value for the 'insertInto' parameter is invalid.");
	}

	var lastStyleElementInsertedAtTop = $i__NM$$style$$_$$loader$lib$addStyles__stylesInsertedAtTop[$i__NM$$style$$_$$loader$lib$addStyles__stylesInsertedAtTop.length - 1];

	if (options.insertAt === "top") {
		if (!lastStyleElementInsertedAtTop) {
			target.insertBefore(style, target.firstChild);
		} else if (lastStyleElementInsertedAtTop.nextSibling) {
			target.insertBefore(style, lastStyleElementInsertedAtTop.nextSibling);
		} else {
			target.appendChild(style);
		}
		$i__NM$$style$$_$$loader$lib$addStyles__stylesInsertedAtTop.push(style);
	} else if (options.insertAt === "bottom") {
		target.appendChild(style);
	} else if (typeof options.insertAt === "object" && options.insertAt.before) {
		var nextSibling = $i__NM$$style$$_$$loader$lib$addStyles__getElement(options.insertInto + " " + options.insertAt.before);
		target.insertBefore(style, nextSibling);
	} else {
		throw new Error("[Style Loader]\n\n Invalid value for parameter 'insertAt' ('options.insertAt') found.\n Must be 'top', 'bottom', or Object.\n (https://github.com/webpack-contrib/style-loader#insertat)\n");
	}
}

function $i__NM$$style$$_$$loader$lib$addStyles__removeStyleElement (style) {
	if (style.parentNode === null) return false;
	style.parentNode.removeChild(style);

	var idx = $i__NM$$style$$_$$loader$lib$addStyles__stylesInsertedAtTop.indexOf(style);
	if(idx >= 0) {
		$i__NM$$style$$_$$loader$lib$addStyles__stylesInsertedAtTop.splice(idx, 1);
	}
}

function $i__NM$$style$$_$$loader$lib$addStyles__createStyleElement (options) {
	var style = document.createElement("style");

	options.attrs.type = "text/css";

	$i__NM$$style$$_$$loader$lib$addStyles__addAttrs(style, options.attrs);
	$i__NM$$style$$_$$loader$lib$addStyles__insertStyleElement(options, style);

	return style;
}

function $i__NM$$style$$_$$loader$lib$addStyles__createLinkElement (options) {
	var link = document.createElement("link");

	options.attrs.type = "text/css";
	options.attrs.rel = "stylesheet";

	$i__NM$$style$$_$$loader$lib$addStyles__addAttrs(link, options.attrs);
	$i__NM$$style$$_$$loader$lib$addStyles__insertStyleElement(options, link);

	return link;
}

function $i__NM$$style$$_$$loader$lib$addStyles__addAttrs (el, attrs) {
	Object.keys(attrs).forEach(function (key) {
		el.setAttribute(key, attrs[key]);
	});
}

function $i__NM$$style$$_$$loader$lib$addStyles__addStyle (obj, options) {
	var style, update, remove, result;

	// If a transform function was defined, run it on the css
	if (options.transform && obj.css) {
	    result = options.transform(obj.css);

	    if (result) {
	    	// If transform returns a value, use that instead of the original css.
	    	// This allows running runtime transformations on the css.
	    	obj.css = result;
	    } else {
	    	// If the transform function returns a falsy value, don't add this css.
	    	// This allows conditional loading of css
	    	return function() {
	    		// noop
	    	};
	    }
	}

	if (options.singleton) {
		var styleIndex = $i__NM$$style$$_$$loader$lib$addStyles__singletonCounter++;

		style = $i__NM$$style$$_$$loader$lib$addStyles__singleton || ($i__NM$$style$$_$$loader$lib$addStyles__singleton = $i__NM$$style$$_$$loader$lib$addStyles__createStyleElement(options));

		update = $i__NM$$style$$_$$loader$lib$addStyles__applyToSingletonTag.bind(null, style, styleIndex, false);
		remove = $i__NM$$style$$_$$loader$lib$addStyles__applyToSingletonTag.bind(null, style, styleIndex, true);

	} else if (
		obj.sourceMap &&
		typeof URL === "function" &&
		typeof URL.createObjectURL === "function" &&
		typeof URL.revokeObjectURL === "function" &&
		typeof Blob === "function" &&
		typeof btoa === "function"
	) {
		style = $i__NM$$style$$_$$loader$lib$addStyles__createLinkElement(options);
		update = $i__NM$$style$$_$$loader$lib$addStyles__updateLink.bind(null, style, options);
		remove = function () {
			$i__NM$$style$$_$$loader$lib$addStyles__removeStyleElement(style);

			if(style.href) URL.revokeObjectURL(style.href);
		};
	} else {
		style = $i__NM$$style$$_$$loader$lib$addStyles__createStyleElement(options);
		update = $i__NM$$style$$_$$loader$lib$addStyles__applyToTag.bind(null, style);
		remove = function () {
			$i__NM$$style$$_$$loader$lib$addStyles__removeStyleElement(style);
		};
	}

	update(obj);

	return function updateStyle (newObj) {
		if (newObj) {
			if (
				newObj.css === obj.css &&
				newObj.media === obj.media &&
				newObj.sourceMap === obj.sourceMap
			) {
				return;
			}

			update(obj = newObj);
		} else {
			remove();
		}
	};
}

var $i__NM$$style$$_$$loader$lib$addStyles__replaceText = (function () {
	var textStore = [];

	return function (index, replacement) {
		textStore[index] = replacement;

		return textStore.filter(Boolean).join('\n');
	};
})();

function $i__NM$$style$$_$$loader$lib$addStyles__applyToSingletonTag (style, index, remove, obj) {
	var css = remove ? "" : obj.css;

	if (style.styleSheet) {
		style.styleSheet.cssText = $i__NM$$style$$_$$loader$lib$addStyles__replaceText(index, css);
	} else {
		var cssNode = document.createTextNode(css);
		var childNodes = style.childNodes;

		if (childNodes[index]) style.removeChild(childNodes[index]);

		if (childNodes.length) {
			style.insertBefore(cssNode, childNodes[index]);
		} else {
			style.appendChild(cssNode);
		}
	}
}

function $i__NM$$style$$_$$loader$lib$addStyles__applyToTag (style, obj) {
	var css = obj.css;
	var media = obj.media;

	if(media) {
		style.setAttribute("media", media)
	}

	if(style.styleSheet) {
		style.styleSheet.cssText = css;
	} else {
		while(style.firstChild) {
			style.removeChild(style.firstChild);
		}

		style.appendChild(document.createTextNode(css));
	}
}

function $i__NM$$style$$_$$loader$lib$addStyles__updateLink (link, options, obj) {
	var css = obj.css;
	var sourceMap = obj.sourceMap;

	/*
		If convertToAbsoluteUrls isn't defined, but sourcemaps are enabled
		and there is no publicPath defined then lets turn convertToAbsoluteUrls
		on by default.  Otherwise default to the convertToAbsoluteUrls option
		directly
	*/
	var autoFixUrls = options.convertToAbsoluteUrls === undefined && sourceMap;

	if (options.convertToAbsoluteUrls || autoFixUrls) {
		css = $i__NM$$style$$_$$loader$lib$addStyles__fixUrls(css);
	}

	if (sourceMap) {
		// http://stackoverflow.com/a/26603875
		css += "\n/*# sourceMappingURL=data:application/json;base64," + btoa(unescape(encodeURIComponent(JSON.stringify(sourceMap)))) + " */";
	}

	var blob = new Blob([css], { type: "text/css" });

	var oldSrc = link.href;

	link.href = URL.createObjectURL(blob);

	if(oldSrc) URL.revokeObjectURL(oldSrc);
}

try{$n__NM$$style$$_$$loader$lib$addStyles.exports.__esModule = $n__NM$$style$$_$$loader$lib$addStyles.exports.__esModule || false;}catch(_){}

/* NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css */

let $n__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css = { id: "NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css", exports: {}};

var $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__content = ($n__NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.exports);

if(typeof $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__content === 'string') $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__content = [[$n__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.id, $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__content, '']];

var $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__transform;
var $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__insertInto;



var $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__options = {"hmr":true}

$i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__options.transform = $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__transform
$i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__options.insertInto = undefined;

var $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__update = ($n__NM$$style$$_$$loader$lib$addStyles.exports)($i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__content, $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__options);

if($i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__content.locals) $n__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.exports = $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__content.locals;

if($n__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.hot) {
	$n__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.hot.accept("!!./node_modules/css-loader/index.js!./test.css", function() {
		var newContent = ($n__NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.exports);

		if(typeof newContent === 'string') newContent = [[$n__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.id, newContent, '']];

		var locals = (function(a, b) {
			var key, idx = 0;

			for(key in a) {
				if(!b || a[key] !== b[key]) return false;
				idx++;
			}

			for(key in b) idx--;

			return idx === 0;
		}($i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__content.locals, newContent.locals));

		if(!locals) throw new Error('Aborting CSS HMR due to changed css-modules locals.');

		$i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__update(newContent);
	});

	$n__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.hot.dispose(function() { $i__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css__update(); });
}
try{$n__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.exports.__esModule = $n__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.exports.__esModule || false;}catch(_){}

/* index */

let $n__index = { id: "index", exports: {}};

console.log($n__NM$$style$$_$$loader$indexDOT$$js$$B$$NM$$css$$_$$loader$indexDOT$$js$$B$$testDOT$$css.exports);

document.body.innerHTML =
  'this text is red<div class="x">this text is blue</div>';

try{$n__index.exports.__esModule = $n__index.exports.__esModule || true;}catch(_){}
})()
