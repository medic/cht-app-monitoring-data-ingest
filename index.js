const dotenv = require('dotenv');
const scrapeInstance = require('./scrape-instance');
const PostgresWarehouse = require('./pg-warehouse');

dotenv.config({
  path: './.env'
});

const monitorParams = {
  user: process.env.MONITORING_USERNAME,
  password: process.env.MONITORING_PASSWORD,
};

const dbParams = {
  user: process.env.PG_USERNAME,
  host: process.env.PG_HOST,
  database: process.env.PG_DATABASE,
  password: process.env.PG_PASSWORD,
  port: process.env.PG_PORT,
};

const klipfolioParams = {
  apiKey: process.env.KLIP_API_KEY,
};

const missingEnvs = Object.keys(dbParams).filter(key => !dbParams[key]);
const missingMonitorParams = Object.keys(monitorParams).filter(key => !monitorParams[key]);
const missingKlipfolioParams = Object.keys(klipfolioParams).filter(key => !klipfolioParams[key]);
if (missingEnvs.length > 0) {
  throw Error(`DB Environment variables are undefined: ${missingEnvs.join(',')}`);
}
if (missingMonitorParams.length > 0) {
  throw Error(`Monitoring Environment variables are undefined: ${missingMonitorParams.join(',')}`);
}
if (missingKlipfolioParams.length > 0) {
  throw Error(`Klipfolio Environment variables are undefined: ${missingKlipfolioParams.join(',')}`);
}

const postgres = new PostgresWarehouse();
(async () => {

  await postgres.connect(dbParams);

  try 
  {
    const monitoringEntries = await postgres.getUrls();
    const scrapeableOptions = monitoringEntries
      .filter(entry => entry.enabled)
      .map(entry => ({
        urlId: entry.id,
        url: entry.url,
        access: entry.access_level,
        klipfolioApiKey: klipfolioParams.apiKey,
        klipfolioClientId: entry.klipfolio_client_id,
        username: monitorParams.user,
        password: monitorParams.password,
      }));

    // should not scrape in parallel due to klipfolio rate limits
    const scrapedData = [];
    for (const scrapeable of scrapeableOptions) {
      const result = await scrapeInstance(scrapeable);
      scrapedData.push(result);
    }
    
    for (const result of scrapedData) {
      await postgres.upload(result);
    }
  }
  finally {
    await postgres.disconnect();
  }

})();
