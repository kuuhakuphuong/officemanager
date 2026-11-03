const { MongoClient } = require("mongodb");

const DEFAULT_DB = "QuanLyToaNha";

// Chuỗi kết nối tới mongos (router của cụm sharded). Ứng dụng luôn đi qua mongos,
// không kết nối trực tiếp vào shard.
function mongoConfig(environment = process.env) {
  const uri = environment.MONGO_URI;
  if (!uri) throw new Error("Missing MongoDB configuration: MONGO_URI");
  return { uri, database: environment.MONGO_DATABASE || DEFAULT_DB };
}

class MongoConnection {
  constructor(config = mongoConfig()) {
    this.config = config;
    this.client = null;
  }

  async connect() {
    if (!this.client) {
      this.client = new MongoClient(this.config.uri, { serverSelectionTimeoutMS: 5000 });
      await this.client.connect();
    }
    return this.client;
  }

  db() {
    if (!this.client) throw new Error("MongoConnection chưa được connect()");
    return this.client.db(this.config.database);
  }

  async close() {
    if (this.client) await this.client.close();
    this.client = null;
  }
}

module.exports = { MongoConnection, mongoConfig, DEFAULT_DB };
