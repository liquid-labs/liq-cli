import dateFormat from 'dateformat'

import { requireEnv } from './lib-changelog-core'

const addEntry = (changelog) => {
  // get the approx start time according to the local clock
  const startTimestampLocal = dateFormat(new Date(), 'UTC:yyyy-mm-dd-HHMM Z')
  // process the 'work unit' data
  const issues = requireEnv('WORK_ISSUES').split('\n')
  const involvedProjects = requireEnv('INVOLVED_PROJECTS').split('\n')

  const newEntry = {
    issues,
    branch          : requireEnv('WORK_BRANCH'),
    startTimestampLocal,
    branchFrom      : requireEnv('CURR_REPO_VERSION'),
    description     : requireEnv('WORK_DESC'),
    workInitiator   : requireEnv('WORK_INITIATOR'),
    branchInitiator : requireEnv('CURR_USER'),
    involvedProjects
  }

  changelog.push(newEntry)
  return newEntry
}

export { addEntry }
