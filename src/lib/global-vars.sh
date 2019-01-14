# Global constants.
_CATALYST_DB="${HOME}/.catalyst"
_CATALYST_ENVS="${_CATALYST_DB}/environments"
_PROJECT_CONFIG='.catalyst-project' #TODO: current file '.catalyst' and the code doesn't make reference to this constant; convert that to 'catalyst-project'
_PROJECT_PUB_CONFIG='.catalyst-pub'
_WORKSPACE_CONFIG='.catalyst-workspace' #TODO: move under _WORKSPACE_DB
_WORKSPACE_DB='.catalyst'
_ORG_ID_URL='https://console.cloud.google.com/iam-admin/settings'
_BILLING_ACCT_URL='https://console.cloud.google.com/billing?folder=&organizationId='

# Global variables.
PACKAGE_FILE=''
CURR_ENV_FILE=''
SOURCE_DIR="$SOURCE_DIR" # TODO: huh?
BASE_DIR=''
WORKSPACE_DIR=''

COMPONENT=''
ACTION=''

# Configurable globals.
ORIGIN_URL='' # can be set externally to avoid interactive questions on 'project init'
