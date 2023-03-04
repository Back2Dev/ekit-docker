import fs from "fs";
import { DateTime } from "luxon";
import dbg from "debug";
const debug = dbg("app:ekit-import");
import mini from "minimist";
import { objectTypeAnnotation } from "@babel/types";
import { MongoClient } from "mongodb";
import { randomId } from "./lib/random.mjs";

const opts = mini(process.argv.slice(2));
if (opts.help) {
  console.log(`
#Usage:
	node scripts/unpack.mjs SID [--db=ekit] [--help] [--clean]
Where
  SID = survey id, eg MAP001
  --db = dbname
  --clean

#Prerequisites
	None

#Processing:
  This command will parse the ../triton/SID/web folder, and insert into the database
  `);
  process.exit(0);
}

const url = "mongodb://localhost:27017";
const client = new MongoClient(url);

// Database Name
const dbName = opts.db || "ekit";
const SID = opts._[0];

const accessByPath = (obj, path) => {
  if (typeof path !== "string") return "";
  const paths = path.split(".");
  return paths.reduce((acc, path) => {
    if (!acc) return "";
    if (acc[path]) return acc[path] || "";
    return "";
  }, obj);
};

const doit = async () => {
  console.log(`Connecting to ${url}/${dbName}/${SID}`);
  await client.connect();
  // console.log("Connected successfully to server");
  const db = client.db(dbName);
  const collection = db.collection(opts.lot || SID);

  if (opts.clean) {
    await collection.deleteMany({});
    await collection.createIndex({ survey_id: 1 });
    await collection.createIndex({ id: 1 });
    await collection.createIndex({ password: 1 });
    await collection.createIndex({ updatedAt: 1 });
    await collection.createIndex({ seqno: 1 });
    await collection.createIndex({
      password: 1,
      id: 1,
      survey_id: 1,
      updatedAt: 1,
    });
  }
  const dir = `../triton/${SID}/web`;
  const files = fs.readdirSync(dir).filter((f) => f.match(/D\d+\.pl$/));
  // .find((f) => f.match(/^D/))
  let n = 0;
  for (let f of files) {
    const file = `${dir}/${f}`;
    debug(`Reading file ${file}`);
    let txt = fs.readFileSync(file, { encoding: "utf8" });
    // Extract last modified from file header
    const m = txt.match(/ts=(\d+)/);
    const when = m[1];
    // Make it look like javascript code
    txt = txt
      .replace(/^#/gm, "//")
      .replace(/^1;/gm, "")
      .replace(/\s+%resp = \(/, "\n  ({")
      .replace(/\s+\);/, "\n})")
      .replace(/','/gm, "':'");
    // debug(txt);
    fs.writeFileSync("file.js", txt, { encoding: "utf8" });
    // Evaluate => object
    const data = eval(txt);
    // debug(data);
    // Cleanups/fixes
    Object.keys(data).forEach((key) => {
      if (data[key] === "") delete data[key];
      else {
        if (data[key].match(/===/)) data[key] = data[key].split(/===/);
        if (key.match(/^_Q/)) {
          data[key.replace(/^_/, "")] = data[key];
          delete data[key];
        }
      }
    });
    data.start = new Date(data.start * 1000);
    if (when) data.updatedAt = new Date(when * 1000);
    data._id = randomId();
    if (!data.survey_id) data.survey_id = SID;
    if (!data.seqno) {
      data.seqno = f.replace(/^D/, "").replace(".pl", "");
    }
    // Save our work
    // fs.writeFileSync("file.json", JSON.stringify(data, null, 2), {
    //   encoding: "utf8",
    // });
    const j = await collection.insertOne(data);
    n = n + 1;
    // debug({ n });
    if (opts.one) process.exit(1);
  }
  console.log(`Saved ${files.length} records to ${dbName}/${SID}`);
  client.close();
};

try {
  doit();
} catch (e) {
  console.error(e);
}
// f
