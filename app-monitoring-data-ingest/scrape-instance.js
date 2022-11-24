const _ = require('lodash');
const btoa = require('btoa');
const fetch = require('node-fetch');

const analyse = require('./analyse');
const fetchKlipDatasourceStatus = require('./fetch-klip-datasource-status');

const scrape = async instance => {
  const { url } = instance;
  try {
    const status = await ping(url);

    if (typeof status === 'string') {
      return {
        urlId: instance.urlId,
        status,
      };
    }

    // public API - not permissions needed
    const monitoring = await fetchWithoutAuth(url, '/api/v1/monitoring');
    console.log(`Monitor for ${url}: ${!!monitoring}`);

    let settings, klipDatasources, forms, users, analysis, logs;
    if (instance.klipfolioClientId) {
      klipDatasources = await fetchKlipDatasourceStatus(instance.klipfolioClientId, instance.klipfolioApiKey);
    }
    
    // user account with online role
    // can't use API due to https://github.com/medic/cht-core/issues/7592
    if (instance.access > 2) {
      users = await fetchWithAuth(url, instance, '/medic/_all_docs?startkey=%22org.couchdb.user:%22&endkey=%22org.couchdb.user:\\ufff0%22&include_docs=true');
    }

    // a user account is required
    if (instance.access > 1) {
      settings = await fetchSettings(url, instance);
      forms = await fetchWithAuth(url, instance, '/medic/_all_docs?startkey=%22form:%22&endkey=%22form:\\ufff0%22');
      analysis = analyse(url, settings, users || [], forms);
      console.log(`Successful analysis of ${url}...`);
    }

    // user account with online role and access to medic-sentinel
    if (instance.access > 3) {
      const timestampOneMonthAgo = new Date().getTime() - 30 * 24 * 60 * 60 * 1000;
      const fetched = await fetchWithAuth(url, instance, `/medic-sentinel/_all_docs?startkey=%22purgelog:${timestampOneMonthAgo}%22&endkey=%22purgelog:\\ufff0%22&include_docs=true`);
      logs = fetched.rows.map(row => row.doc);
    }

    return {
      urlId: instance.urlId,
      status: 'ok',
      settings,
      klipDatasources,
      monitoring,
      analysis,
      logs,
    };
  } catch (e) {
    console.log(`CRASH`, e);
    return {
      urlId: instance.urlId,
      status: 'crash: ' + e.message,
    };
  }
};

const fetchWithoutAuth = async (url, path, body) => {
  const absoluteUrl = url + path;
  console.log(`Fetching ${absoluteUrl}...`);
  const fetched = await fetch(absoluteUrl, {
    method: body ? 'POST' : 'GET',
    body: JSON.stringify(body),
    headers: {
      'Content-Type': 'application/json',
    },
  });

  if (!fetched.ok) {
    throw new Error(`Error response: ${fetched.status}`);
  }

  if (fetched.headers.get('content-type').startsWith('text/html')) {
    return false;
  }

  return fetched.json();
};

const fetchWithAuth = async (url, instance, path, body) => {
  const absoluteUrl = url + path;
  console.log(`Fetching ${absoluteUrl}...`);
  const authString = btoa(`${instance.username}:${instance.password}`);
  const fetched = await fetch(absoluteUrl, {
    method: body ? 'POST' : 'GET',
    body: JSON.stringify(body),
    headers: {
      Authorization: 'Basic ' + authString,
      'Content-Type': 'application/json',
    },
  });

  return fetched.json();
};

const fetchSettings = async (url, instance) => {
  let result;
  try {
    result = await fetchWithAuth(url, instance, '/medic/settings');
  }
  catch (e) { }
  finally {
    if (!result || result.error) {
      console.log('Using ddoc for settings');
      result = await fetchWithAuth(url, instance, '/medic/_design/medic');
    }
  }

  return result;
};

const ping = url => fetch(url)
  .catch(e => {
    console.log(`Skipping ${url}. ${e}`);
    return `error: ${e.errno}`;
  });

module.exports = scrape;
