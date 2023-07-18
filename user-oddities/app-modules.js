
const Fs = require('fs/promises');
const fetch = require('node-fetch');

const fetchJson = async (url, path, options) => (await fetch(`${url}/${path}`, options)).json();

const fetchAppConfigurations = async () => {
    const json = await Fs.readFile('./app-config/app-settings.json');
    return JSON.parse(json);;
};

const fetchDocsFromKeys = async (keys, HOSTNAME, basicAuthHeader ) => {
    const raw = await fetchJson(HOSTNAME, '/medic/_all_docs?include_docs=true', {
        method: 'POST',
        headers: [
            ['Content-Type', 'application/json'],
            basicAuthHeader
        ],
        body: JSON.stringify({ keys }),
    });

    return raw.rows.reduce((agg, curr) => {
        if (!curr.doc) return agg;
        return Object.assign(agg, { [curr.id]: curr });
    }, {});
};

const logIfDifferent = (actual, expected, message) => {
  if (expected !== actual) {
    console.log(message, ':', actual, 'vs', expected);
  }
}

module.exports = {
  fetchAppConfigurations,
  fetchDocsFromKeys,
  fetchJson,
  logIfDifferent
}