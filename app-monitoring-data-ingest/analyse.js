const _ = require('lodash');

module.exports = (url, settingsDoc, users, forms) => {
  const settings = settingsDoc.app_settings || settingsDoc.settings;
  const userDocs = users.rows ? users.rows
    .filter(user => user.doc && !user.doc.tombstone) : [];

  const roleToUserDoc = userDocs.reduce((agg, { doc }) => {
    if (!doc.roles) {
      return agg;
    }

    for (const role of doc.roles) {
      agg[role] = _.uniqBy([...(agg[role] || []), doc], '_id');
    }
    return agg;
  }, {});

  const permissions = analysePermissions(roleToUserDoc, settings.permissions);

  const validForms = forms && forms.rows && forms.rows.filter(row => !row.id.endsWith('____tombstone'));
  const isContactForm = doc => doc.id.startsWith('form:contact:');
  const parseRev = rev => parseInt(rev && rev.split('-')[0]) || 0;
  const offlineRoles = settings.roles ? Object.keys(settings.roles).filter(role => settings.roles[role].offline) : [];
  const offlineUsers = _.uniq(_.flatten(offlineRoles.map(role => roleToUserDoc[role])).filter(x => x).map(user => user._id));

  const result = {
    url,
    status: 'ok',
    numberOfUsers: userDocs.length,
    numberOfRoles: Object.keys(roleToUserDoc).length,
    numberOfOfflineUser: offlineUsers.length,
    isDeclarativeConfig: !!settings.tasks && !!settings.tasks.rules && settings.tasks.rules.includes('__esModule'),
    numberOfConfigurableHierarchyContactTypes: settings.contact_types ? settings.contact_types.length : 'n/a',
    enabledPurging: settings.purge && !!settings.purge.fn || false,
    dhisDataSourceCount: Array.isArray(settings.dhis_data_sets) && settings.dhis_data_sets.length,
    uhcEnabled: settings.uhc && !!settings.uhc.visit_count || 'disabled',
    numberOfContactForms: validForms ? validForms.filter(isContactForm).length : 'unknown',
    numberOfAppForms: validForms ? validForms.filter(doc => !isContactForm(doc)).length : 'unknown',
    numberOfTargets: settings.tasks && settings.tasks.targets && settings.tasks.targets.items && settings.tasks.targets.items.length || 'n/a',
    numberOfTaskSchedulesNonDeclarative: settings.tasks && settings.tasks.schedules && settings.tasks.schedules.length || 'n/a',
    countOfJsonReplications: settings.replications && settings.replications.length || 'n/a',
    countOfJsonRegistrations: settings.registrations && settings.registrations.length || 'n/a',
    countOfJsonPatient_reports: settings.patient_reports && settings.patient_reports.length || 'n/a',
    countOfJsonSchedules: settings.schedules && settings.schedules.length || 'n/a',
    countOfJsonForms: typeof settings.forms === 'object' && Object.keys(settings.forms).length,
    countOfOutboundPushes: typeof settings.outbound === 'object' && Object.keys(settings.outbound).length || 'n/a',
    appSettingRevs: parseRev(settingsDoc._rev),
    formRevs: _.sum(validForms.map(doc => parseRev(doc.value.rev))),
  };

  for (const permission of Object.keys(permissions)) {
    result[`permission.${permission}`] = permissions[permission];
  }

  if (settings.transitions) {
    for (const transition of Object.keys(settings.transitions)) {
      const val = settings.transitions[transition];
      result[`transitions.${transition}`] = (val && !val.disable) ? 'true' : '';
    }
  }

  return result;
};


const analysePermissions = (roleToUserDoc, permissions) => {
  if (!permissions) {
    return {};
  }

  // 2.x
  if (Array.isArray(permissions)) {
    return permissions.reduce((agg, permission) => {
      const users = permission.roles.map(role => {
        const users = roleToUserDoc[role] || [];
        return users.map(user => user._id);
      });
  
      agg[permission.name] = _.uniq(_.flatten(users).filter(u => u)).length;
      return agg;
    }, {});
  }

  return Object.keys(permissions).reduce((agg, permission) => {
    const users = permissions[permission].map(role => {
      const users = roleToUserDoc[role] || [];
      return users.map(user => user._id);
    });

    agg[permission] = _.uniq(_.flatten(users).filter(u => u)).length;
    return agg;
  }, {});
}
