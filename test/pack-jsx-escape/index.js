import React from "react";
import ReactDOM from "react-dom";

function App({ prop1 }) {
  return (
    <div>
      <div>Next div has &amp;nbsp;</div>
      <div id="with-nbsp">&nbsp;</div>
      <div>Next div has emoji!</div>
      <div id="with-emoji">
       😀 😁 😂 🤣 😃 😄 😅 😆 😉 😊 😋 😎 😍 😘 🥰 😗 😙 😚 ☺️ 🙂 🤗 🤩 🤔 🤨 😐 😑 😶 🙄 😏 😣 😥 😮 🤐 😯 😪 😫 😴 😌 😛 😜 😝 🤤 😒 😓 😔 😕 🙃 🤑 😲 ☹️ 🙁 😖 😞 😟 😤 😢 😭 😦 😧 😨 😩 🤯 😬 😰 😱 🥵 🥶 😳 🤪 😵 😡 😠 🤬 😷 🤒 🤕 🤢 🤮 🤧 😇 🤠 🤡 🥳 🥴 🥺 🤥 🤫 🤭 🧐 🤓 😈 👿 👹 👺 💀 👻 👽 🤖 💩 😺 😸 😹 😻 😼 😽 🙀 😿 😾
      </div>
      <div>Next div has emoji mixed up with "text"</div>
      <div>{prop1}</div>
    </div>
  );
}

ReactDOM.render(<App prop1="Emoji from prop: 🤮 🤧 😇 🤠 🤡"/>, document.getElementById("root"));
