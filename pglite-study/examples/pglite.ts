// https://www.blackslate.io/articles/pglite-run-postgresql-locally-in-node-bun-and-also-in-browser
import { PGlite } from "@electric-sql/pglite";

const db = new PGlite();
// persist data in local files
// const db = new PGlite("./data");

console.log("start db");

console.log("create database");
let results = await db.exec(`
CREATE TABLE IF NOT EXISTS employee (
    id SERIAL PRIMARY KEY,
    name TEXT,
    age INTEGER,
    role TEXT
);`);
console.log(results);

console.log("show tables");
results = await db.query(
  `SELECT * FROM pg_catalog.pg_tables where schemaname='public';`,
);
console.log(results.rows.map((r) => r.tablename));

console.log("insert records");
results = await db.exec(`
INSERT INTO employee (name, age, role) VALUES ('Tom', 40, 'Senior Developer');
INSERT INTO employee (name, age, role) VALUES ('Aditya', 20, 'Junior Developer');
INSERT INTO employee (name, age, role) VALUES ('Raja', 50, 'Manager');
`);
const { affectedRows } = results.at(-1);
console.log({ affectedRows });

console.log("query database");
results = await db.query(`SELECT * from employee;`);
console.log(results.rows);

results = await db.query(`SELECT * from employee where age > $1;`, [20]);
console.log(results.rows);

results = await db.query(`SELECT * from employee where role like $1;`, [
  "%Developer%",
]);
console.log(results.rows);

console.log("close");
await db.close();
