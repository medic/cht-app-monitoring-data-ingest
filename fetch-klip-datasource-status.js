const fetch = require('node-fetch');

const fetchKlipDatasourceStatus = async (clientId, apiKey) => {
  const datasourceStatus = await fetchKlipApi(apiKey, `/datasources?client_id=${clientId}&limit=100`);
  if (!datasourceStatus.meta.success) {
    throw new Error(`Fetch unsuccessful: ${datasourceStatus.meta}`);
  }

  return datasourceStatus.data.datasources;
};

const pause = ts => new Promise(resolve => setTimeout(() => resolve(), ts));

const fetchKlipApi = async (apiKey, path) => {
  try {
    const fetchUrl = `https://app.klipfolio.com/api/1${path}`;
    console.log(`Fetching ${fetchUrl}`);

    const result = await fetch(fetchUrl, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'kf-api-key': apiKey,
      },
    });
    return result.json();
  }
  catch (e) {
    console.error(e);
    await pause(5 * 60 * 1000);
    return fetchKlipApi(path);
  }
};

module.exports = fetchKlipDatasourceStatus;
