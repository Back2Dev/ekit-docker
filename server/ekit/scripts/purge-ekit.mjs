import mysql from "mysql2/promise";
import fs from "fs";
import dbg from "debug";
const debug = dbg("app:purge");
// the "opts" object will contain all the command line parameters and options
// So the first parameter will be in the opts._ array, eg the first one will be in opts._[0]
// eg if run with --debug, then opts.debug will be true
import mini from "minimist";
const opts = mini(process.argv.slice(2));

if (opts.help) {
  console.log(`
#Usage:
	node scripts/purge-ekit.js [--dry-run]
Where
  --dry-run means just report on what you want to purge

#Processing:
  This command will do the following
    - Clean up all the old stuff
      `);
  process.exit(0);
}

const delta = 6 * 30 * 24 * 60 * 60; // 6 months
const cutoff = Math.floor(Date.now() / 1000 - delta);

const tables =
  "101 001 002 003 004 005 006 007 008 009 010 010A 011 012 018 026".split(
    /\s+/
  );
const eventTables = tables.map((n) => `MAP${n}_E`);
const formTables = tables.map((n) => `MAP${n}`);
const sqlCmds = [];
eventTables.forEach((tbl) =>
  sqlCmds.push(`DELETE FROM ${tbl} where ts < ${cutoff}`)
);
const doit = async () => {
  const mydb = {
    host: process.env.EKSERVER || "192.168.1.206",
    user: "root",
    password: process.env.PASSWORD || "my-secret-pw",
    database: "vhost_ekit",
  };
  debug(`Connecting to mysql...`, mydb);
  var MysqlCon = await mysql.createConnection(mydb);

  try {
    formTables.forEach((tbl) =>
      sqlCmds.push(
        `delete from ${tbl} where uid in (select distinct uid from MAP101 where ts> ${cutoff});`
      )
    );
  } catch (e) {
    console.error("Error in do: " + e.message);
  }
  let buf = sqlCmds.join(";\n");
  fs.writeFileSync(`./purge.sql`, buf);
  MysqlCon.end(function (err) {
    debug(err);
  });
};

doit();

/** SQL CODE
 
DROP TABLE IF EXISTS DELETIONS;
CREATE TABLE `DELETIONS` (
  `PWD` varchar(12) NOT NULL,
  `UID` varchar(50) DEFAULT NULL,
  `stat` int(11) DEFAULT NULL,
  `FULLNAME` varchar(60) DEFAULT NULL,
  `TS` int(11) DEFAULT NULL,
  `EXPIRES` int(11) DEFAULT NULL,
  `SEQ` int(11) DEFAULT NULL,
  `REMINDERS` int(11) DEFAULT NULL,
  `EMAIL` varchar(80) DEFAULT NULL,
  `BATCHNO` int(11) DEFAULT NULL,
  `STOP_FLAG` int(11) DEFAULT NULL,
  `SID` varchar(12) DEFAULT NULL,
  ORIG_WHEN varchar(20) DEFAULT NULL
);


insert into DELETIONS select *,'MAP001',from_unixtime(ts) from MAP001 where uid in (select distinct uid from MAP101);
insert into DELETIONS select *,'MAP002',from_unixtime(ts) from MAP002 where uid in (select distinct uid from MAP101);
insert into DELETIONS select *,'MAP003',from_unixtime(ts) from MAP003 where uid in (select distinct uid from MAP101);
insert into DELETIONS select *,'MAP004',from_unixtime(ts) from MAP004 where uid in (select distinct uid from MAP101);
insert into DELETIONS select *,'MAP005',from_unixtime(ts) from MAP005 where uid in (select distinct uid from MAP101);
insert into DELETIONS select PWD,UID,stat,fullname,ts,expires,seq,reminders,email,batchno,stop_flag,'MAP010',from_unixtime(ts) from MAP010 where uid in (select distinct uid from MAP101);
insert into DELETIONS select *,'MAP010A',from_unixtime(ts) from MAP010A where uid in (select distinct uid from MAP101);

select * from DELETIONS order by ts;
select * from DELETIONS where uid=726455;
 */
