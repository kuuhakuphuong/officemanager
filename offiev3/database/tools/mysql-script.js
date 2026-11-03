// Tách file .sql MySQL thành từng câu lệnh để chạy qua mysql2 (driver không hiểu DELIMITER).
// Quy ước: dòng bắt đầu bằng "--" và khối "/* ... */" đứng riêng được bỏ qua.
function splitSql(source) {
  const statements = [];
  let delimiter = ";";
  let buffer = "";
  let inBlockComment = false;
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (inBlockComment) {
      if (line.includes("*/")) inBlockComment = false;
      continue;
    }
    if (!buffer.trim() && /^DELIMITER\s+/i.test(line)) {
      delimiter = line.split(/\s+/)[1];
      continue;
    }
    if (!buffer.trim() && (line === "" || line.startsWith("--"))) continue;
    if (!buffer.trim() && line.startsWith("/*")) {
      if (!line.includes("*/")) inBlockComment = true;
      continue;
    }
    buffer += `${rawLine}\n`;
    if (buffer.trimEnd().endsWith(delimiter)) {
      const statement = buffer.trimEnd().slice(0, -delimiter.length).trim();
      if (statement) statements.push(statement);
      buffer = "";
    }
  }
  if (buffer.trim()) statements.push(buffer.trim());
  return statements;
}

// Chạy toàn bộ file bằng một kết nối mysql2 (promise). `database` thay thế tên CSDL trong script.
async function runSqlFile(connection, source, database) {
  const text = database ? source.replaceAll("QLToaNha_BCNF", database) : source;
  const results = [];
  for (const statement of splitSql(text)) results.push(await connection.query(statement));
  return results;
}

module.exports = { splitSql, runSqlFile };
