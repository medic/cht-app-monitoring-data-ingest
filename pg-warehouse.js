const { Client } = require('pg');

class PostgresWarehouse {
  async connect(params) {
    console.log(`Connecting to Postgres @ ${params.host}`);
    this.client = new Client(params);
    await this.client.connect();
    console.log('Connected');
  }

  async getUrls() {
    if (!this.client) {
      throw Error('Attempted to upload, but there is no connection');
    }

    const query = `SELECT id, url, access_level, enabled FROM monitoring_urls;`;
    const result = await this.client.query(query);
    if (result.rowCount === 0) {
      throw Error(`No urls selected`);
    }

    return result.rows;
  }

  async upload(result) {
    if (!this.client) {
      throw Error('Attempted to upload, but there is no connection');
    }

    if (result.status !== 'ok') {
      await queryInsertDoc(this.client, result.urlId, 'error', { status: result.status });
      return;
    }

    if (result.settings && result.settings.settings) {
      const settingsDoc = result.settings.settings;
      if (settingsDoc.purge) {
        delete settingsDoc.purge.fn;
      }

      if (settingsDoc.tasks) {
        delete settingsDoc.tasks.rules;
      }

      delete settingsDoc.contact_summary;
    }

    await queryInsertDoc(this.client, result.urlId, 'analysis', result.analysis);
    await queryInsertDoc(this.client, result.urlId, 'settings', result.settings);
    await queryInsertDoc(this.client, result.urlId, 'monitoring', result.monitoring);

    for (const log of result.logs || []) {
      await queryInsertLog(this.client, result.urlId, log);
    }
  }
  
  async disconnect() {
    if (!this.client) {
      throw Error('Attempted to close, but there is no connection');
    }

    console.log('Closing Postgres Connection');
    await this.client.end();
    console.log('Closed');
    delete this.client;
  }
}

const queryInsertDoc = async (client, urlId, docType, doc) => {
  if (!doc) {
    return;
  }

  const query = `INSERT INTO monitoring_docs (url_id, doctype, doc) VALUES ($1, $2, $3);`;
  const insertParams = [urlId, docType, JSON.stringify(doc)];
  const result = await client.query(query, insertParams);
  if (result.rowCount === 0) {
    throw Error(`No rows inserted for ${urlId} at ${result}`);
  }

  console.log(`${result.rowCount} is inserted successfully`);
  return result;
};

const queryInsertLog = (client, urlId, log) => {
  const query = `INSERT INTO monitoring_logs (url_id, doc_id, doc) VALUES ($1, $2, $3) ON CONFLICT ON CONSTRAINT monitoring_logs_idx_constraint DO NOTHING;`;
  const insertParams = [urlId, log._id, JSON.stringify(log)];
  return client.query(query, insertParams);
};

module.exports = PostgresWarehouse;

