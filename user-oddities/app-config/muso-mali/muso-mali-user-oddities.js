const { logIfDifferent } = require('../../app-modules')

const musoMaliUserOddities = (userDocsInMedicDb, userDocsInUsersDb, facilityDocs, contactDocs) => {
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

        if (facilityDoc.type === 'health_center' || facilityDoc.contact_type === 'c40_chw_area') {
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
            if (facilityDoc.aire_de_sante === 'Yirimadio') {
                if (facilityDoc.is_in_proccm !== "true") {
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
}

module.exports = {
    musoMaliUserOddities
}