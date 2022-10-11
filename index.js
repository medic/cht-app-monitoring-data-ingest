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

const missingEnvs = Object.keys(dbParams).filter(key => !dbParams[key]);
const missingMonitorParams = Object.keys(monitorParams).filter(key => !monitorParams[key]);
if (missingEnvs.length > 0) {
  throw Error(`Environment variables are undefined: ${missingEnvs.join(',')}`);
}
if (missingMonitorParams.length > 0) {
  throw Error(`Environment variables are undefined: ${missingMonitorParams.join(',')}`);
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
        username: monitorParams.user,
        password: monitorParams.password,
      }));

    const promisesToScrape = scrapeableOptions.map(scrapeInstance);
    const scrapedData = await Promise.all(promisesToScrape);
    for (const result of scrapedData) {
      await postgres.upload(result);
    }
  }
  finally {
    await postgres.disconnect();
  }

})();