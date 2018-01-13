import all, {a1, a2, a3} from "./a";
export default function() {
  console.log("Русский", process.env.NODE_ENV,
              process.env.NODE_ENV == "development" ? "разработка" : "релиз!");
}
