const { expect } = require('chai');
const fetch = require('node-fetch');

const USERNAME = 'admin';
const PASSWORD = 'pass';
const HOSTNAME = 'http://localhost:5988';
const basicAuthHeader = ['Authorization', 'Basic ' + Buffer.from(USERNAME + ':' + PASSWORD).toString('base64')];
const fetchJson = async (url, path, options) => (await fetch(`${url}/${path}`, options)).json();

const usersToIgnore = ['admin', 'medic-api', 'medic-sentinel', 'muso-sih', 'horticulturalist'];

(async () => {
  const allUserDbDocs = await fetchJson(HOSTNAME, '/_users/_all_docs?include_docs=true', { headers: [basicAuthHeader] });
  const userDocsInUsersDb = allUserDbDocs.rows
    .filter(row => !row.id.startsWith('_design/'))
    .filter(row => !usersToIgnore.map(username => `org.couchdb.user:${username}`).includes(row.doc._id));
  const userDocIds = userDocsInUsersDb.map(user => user.doc._id);
  const userDocsInMedicDb = await fetchDocsFromKeys(userDocIds);

  const facilityIds = userDocsInUsersDb.map(user => user.doc.facility_id);
  const facilityDocs = await fetchDocsFromKeys(facilityIds);

  const contactIds = Object.values(userDocsInMedicDb).map(user => user.doc.contact_id);
  const contactDocs = await fetchDocsFromKeys(contactIds);

  expect(userDocsInUsersDb.length).to.eq(userDocIds.length, 'Expect all user docs in _users to have a corresponding doc in medic db.');

  
  for (let i = 0; i < userDocsInUsersDb.length; ++i) {
    const username = userDocsInUsersDb[i].id;
    if (!Object.keys(userDocsInMedicDb).includes(username)) {
      console.log('No user doc in Medic DB', `for user ${username}`);
      continue;
    }

    const userDocInMedicDb = userDocsInMedicDb[username].doc;
    const { facility_id, contact_id } = userDocInMedicDb;

    // logIfDifferent(docInMedicDb.facility_id, docInMedicDb.facility_id, `Facility_ids in _users and medic do not match for user ${username}`);
    if (!Object.keys(facilityDocs).includes(facility_id)) {
      if (!userDocInMedicDb.roles.includes('national_admin')) { //Skip pm accounts for which a facility is not required.
        console.log(`Facility document does not exist for non-pm user ${username}`, ':', facility_id);
      } 
      continue;
    }

    if (!Object.keys(contactDocs).includes(contact_id)) {
      if (!userDocInMedicDb.roles.includes('national_admin')) {
        console.log(`Contact document does not exist for non-pm user ${username}`, ':', contact_id);
      }
      continue;
    }
    const facilityDoc = facilityDocs[userDocInMedicDb.facility_id].doc;
    const contactDoc = contactDocs[userDocInMedicDb.contact_id].doc;

    if (!contactDoc.is_active) {
      // console.log(`Chw user ${username} does not set is_active on contact doc ${contact_id}`);
      continue;
    }

    if (facilityDoc.type === 'health_center' || facilityDoc.contact_type === 'c40_chw_area' ) {
      logIfDifferent(contactDoc.role, 'chw', `Chw user does not set role in contact doc ${username} with ${contact_id}`);

      //Flag CHWs not having the correct roles "chw_uhc" and those misconfigured with "supervisor"/"national_admin".
      if (!userDocInMedicDb.roles.includes('chw_uhc')) {
        console.log(`Chw user does not include role 'chw_uhc'`, username, JSON.stringify(userDocInMedicDb.roles));
      }
      if (userDocInMedicDb.roles.includes('supervisor')) {
        console.log(`Chw user should not include role 'supervisor'`, username, JSON.stringify(userDocInMedicDb.roles));
      }
      if (userDocInMedicDb.roles.includes('national_admin')) {
        console.log(`Chw user should not include role 'national_admin'`, username, JSON.stringify(userDocInMedicDb.roles));
      }

      const uhcRole = userDocInMedicDb.roles.includes('chw_uhc');
      const uhcContact = !!contactDoc.is_uhc_enabled;
      if (uhcRole !== uhcContact) {
        console.log(`Chw user ${username} with contact ${contact_id} has inconsistent role:chw_uhc vs contact.is_uhc_enabled (role:${uhcRole} is_uhc_enabled:${uhcContact})`);
      }

       // Flag CHWs in Yirimadio and other CHWs area not having the tag is_in_proccm set to true
      if(facilityDoc.aire_de_sante === 'Yirimadio'){
        if(facilityDoc.is_in_proccm !== "true"){
          console.log(`Chw's Health Falicity with the ID ${facilityDoc._id} should have 'is_in_proccm' set to true vs `, JSON.stringify(facilityDoc.is_in_proccm));
        }
      }

    } else if (facilityDoc.type === 'district_hospital' || facilityDoc.contact_type === 'c30_supervisor_area') {

      //Flag supervisors who are misconfigured with "chw_uhc"/"national_admin" roles and those not having "supervisor".
      if (userDocInMedicDb.roles.includes('chw_uhc')) {
        console.log(`Supervisor user should not include role 'chw_uhc'`, username, JSON.stringify(userDocInMedicDb.roles));
      }
      if (userDocInMedicDb.roles.includes('chw_uhc')) {
        console.log(`Supervisor user should not include role 'national_admin'`, username, JSON.stringify(userDocInMedicDb.roles));
      }
      if (!userDocInMedicDb.roles.includes('supervisor')) {
        console.log(`Supervisor user does not include role 'supervisor'`, username, JSON.stringify(userDocInMedicDb.roles));
      }

      logIfDifferent(contactDoc.role, 'chw_supervisor', `Supervisor user does not set role in contact doc. ${username} with ${contact_id}`);
    } else {
      console.log(`User is not a child of a health_clinic or a district_hospital`, username);
    }
  }




  console.log(`${userDocsInUsersDb.length} total users`);
  const notActive = Object.values(contactDocs).filter(d => !d.doc.is_active).map(d => d.id);
  console.log(`${notActive.length} in-active users`);
})();

const logIfDifferent = (actual, expected, message) => {
  if (expected !== actual) {
    console.log(message, ':', actual, 'vs', expected);
  }
}

const logIfSame = (actual, expected, message) => {
  if (expected === actual) {
    console.log(message, ':', actual, 'vs', expected);
  }
}

const fetchDocsFromKeys = async keys => {
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