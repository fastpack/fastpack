function line(cls, prop, descriptor) {
  let orig = descriptor.value;
  return Object.assign({}, descriptor, {
    value: function() {
      orig.apply(this, arguments);
      this.constructor.greetings.push("---------\n");
    }
  });
}

function nl(cls, prop, descriptor) {
  let orig = descriptor.value;
  return Object.assign({}, descriptor, {
    value: function() {
      orig.apply(this, arguments);
      this.constructor.greetings.push("\n");
    }
  });
}

@(cls => cls.greetings.push("---------\n") && cls)
@(cls => cls.greetings.push("Greetings:\n") && cls)
class Greeting {
  static greetings = [];

  constructor(name) {
    this.name = name;
  }

  @line
  @nl
  greet() {
    let greeting = `Hello, ${this.name}!`;
    this.constructor.greetings.push(greeting);
  }
}

let alice = new Greeting("Alice");
alice.greet();
let bob = new Greeting("Bob");
bob.greet();
document.getElementById(
  "root"
).innerHTML = `<pre>${Greeting.greetings.join("")}</pre>`;
