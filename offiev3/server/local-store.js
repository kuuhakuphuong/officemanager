const fs = require("node:fs/promises");
const path = require("node:path");
const { randomUUID } = require("node:crypto");

const collections = new Set(["companies", "offices", "contracts", "services", "employees"]);

class LocalStore {
  constructor(filePath) {
    this.filePath = filePath;
  }

  async read() {
    try {
      return JSON.parse(await fs.readFile(this.filePath, "utf8"));
    } catch (error) {
      if (error.code === "ENOENT") return {};
      throw error;
    }
  }

  async write(data) {
    await fs.mkdir(path.dirname(this.filePath), { recursive: true });
    const temporaryPath = `${this.filePath}.tmp`;
    await fs.writeFile(temporaryPath, JSON.stringify(data, null, 2), "utf8");
    await fs.rename(temporaryPath, this.filePath);
  }

  async list(collection) {
    this.assertCollection(collection);
    return (await this.read())[collection] || [];
  }

  async create(collection, fields) {
    this.assertCollection(collection);
    const data = await this.read();
    const record = { id: randomUUID(), ...fields };
    data[collection] = [...(data[collection] || []), record];
    await this.write(data);
    return record;
  }

  async update(collection, id, fields) {
    this.assertCollection(collection);
    const data = await this.read();
    const rows = data[collection] || [];
    const index = rows.findIndex((row) => row.id === id);
    if (index === -1) return null;
    const record = { ...rows[index], ...fields, id };
    rows[index] = record;
    data[collection] = rows;
    await this.write(data);
    return record;
  }

  async remove(collection, id) {
    this.assertCollection(collection);
    const data = await this.read();
    const rows = data[collection] || [];
    const nextRows = rows.filter((row) => row.id !== id);
    if (nextRows.length === rows.length) return false;
    data[collection] = nextRows;
    await this.write(data);
    return true;
  }

  assertCollection(collection) {
    if (!collections.has(collection)) throw new Error("Unknown collection");
  }
}

module.exports = { LocalStore, collections };
