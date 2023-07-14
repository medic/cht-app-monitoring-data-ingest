const { expect } = require('chai');
const fetch = require('node-fetch');
const { fetchAppConfigurations, fetchDocsFromKeys, fetchJson } = require('./app-modules');
const { musoMaliUserOddities } = require('./app-config/muso-mali/muso-mali-user-oddities');
const { mohMaliChwUserOddities } = require('./app-config/moh-mali-chw/moh-mali-chw-user-oddities');

(async () => {
    const appConfigs = await fetchAppConfigurations();
    for (const appConfig of appConfigs) {
        // set basic authentication
        const basicAuthHeader = ['Authorization', 'Basic ' + Buffer.from(appConfig.USERNAME + ':' + appConfig.PASSWORD).toString('base64')];
        const allUserDbDocs = await fetchJson(appConfig.HOSTNAME, '/_users/_all_docs?include_docs=true', { headers: [basicAuthHeader] });
        const userDocsInUsersDb = allUserDbDocs.rows
            .filter(row => !row.id.startsWith('_design/'))
            .filter(row => !appConfig.USERTOIGNORE.map(username => `org.couchdb.user:${username}`).includes(row.doc._id));
        const userDocIds = userDocsInUsersDb.map(user => user.doc._id);
        const userDocsInMedicDb = await fetchDocsFromKeys(userDocIds, appConfig.HOSTNAME, basicAuthHeader);

        const facilityIds = userDocsInUsersDb.map(user => user.doc.facility_id);
        const facilityDocs = await fetchDocsFromKeys(facilityIds, appConfig.HOSTNAME, basicAuthHeader);

        const contactIds = Object.values(userDocsInMedicDb).map(user => user.doc.contact_id);
        const contactDocs = await fetchDocsFromKeys(contactIds, appConfig.HOSTNAME, basicAuthHeader);
        expect(userDocsInUsersDb.length).to.eq(userDocIds.length, 'Expect all user docs in _users to have a corresponding doc in medic db.');

        switch (appConfig.APPNAME) {
            case 'muso-mali':
                musoMaliUserOddities(userDocsInMedicDb, userDocsInUsersDb, facilityDocs, contactDocs);
                break;
        }

        console.log(`${userDocsInUsersDb.length} total users`);
        const notActive = Object.values(contactDocs).filter(d => !d.doc.is_active).map(d => d.id);
        console.log(`${notActive.length} in-active users`);
    }
})();


/*
{
        "APPNAME": "localhost",
        "USERNAME": "medic",
        "PASSWORD": "password",
        "HOSTNAME": "http://localhost:5988",
        "USERTOIGNORE": [
            "admin",
            "medic-api",
            "medic-sentinel",
            "muso-sih",
            "horticulturalist"
        ],
        "ROLE": [
            "chw_uhc",
            "supervisor",
            "health_center",
            "national_admin",
            "horticulturalist"
        ]
    },

    */