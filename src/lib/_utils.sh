# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

echoerr() {
  echo "${red}$*${reset}" >&2
}

echoerrandexit() {
  local MSG="$1"
  local EXIT_CODE="${2:-10}"
  echoerr "$MSG"
  exit $EXIT_CODE
}

colorerr() {
  # TODO: in the case of long output, it would be nice to notice whether we saw
  # error or not and tell the user to scroll back and check the logs. e.g., if
  # we see an error and then 20+ lines of stuff, then emit advice.
  (trap 'EXIT_STATUS=$?; tput sgr0; exit $EXIT_STATUS' EXIT; eval "$* 2> >(echo -n \"${red}\"; cat -;)")
}

# TODO: is this better? We switched to it for awhile, but there were problems.
# The reasons for both the initial switch and the switchback are now obscured
# but may have been due to failure of the original code to exit with the
# underling error status from the eval, which has since been fixed. The
# switchback was, in part, because of problems with syncronous calls. Of course,
# it didn't wait as we would like, but it was also causing functional problems
# with... somethnig.
# TODO: We are currently not using colorerrbg anywhere.
colorerrbg() {
  (eval "$@" 2>&1>&3|sed 's/^\(.*\)$/'$'\e''[31m\1'$'\e''[m/'>&2)3>&1 &
}

ensureConfig() {
  mkdir -p "$_CATALYST_DB"
  mkdir -p "$_CATALYST_ENVS"
}

exitUnknownGlobal() {
  print_usage
  echoerr "No such component or global action '$COMPONENT'."
  exit 1
}

exitUnknownAction() {
  print_${COMPONENT}_usage
  if [[ -z "$ACTION" ]]; then
    echoerr "Must specify action."
  else
    echoerr "Unknown action '$ACTION' for component '$COMPONENT'."
  fi
  exit 1
}

findFile() {
  local SEARCH_DIR="${1}"
  local FILE_NAME="${2}"
  local RES_VAR="${3}"
  local FOUND_FILE

  while SEARCH_DIR="$(cd "$SEARCH_DIR"; echo $PWD)" && [[ "${SEARCH_DIR}" != "/" ]]; do
    FOUND_FILE=`find -L "$SEARCH_DIR" -maxdepth 1 -mindepth 1 -name "${FILE_NAME}" -type f | grep "${FILE_NAME}" || true`
    if [ -z "$FOUND_FILE" ]; then
      SEARCH_DIR="$SEARCH_DIR/.."
    else
      break
    fi
  done

  if [ -z "$FOUND_FILE" ]; then
    echoerr "Could not find '${FILE_NAME}' config file in any parent directory."
    return 1
  else
    eval $RES_VAR="$FOUND_FILE"
  fi
}

sourceFile() {
  local SEARCH_DIR="${1}"
  local FILE_NAME="${2}"
  local PROJFILE
  findFile "$SEARCH_DIR" "$FILE_NAME" PROJFILE && {
    source "$PROJFILE"
    BASE_DIR="$( cd "$( dirname "${PROJFILE}" )" && pwd )"
    return 0
  }
}

sourceCatalystfile() {
  sourceFile "${PWD}" '.catalyst'
  return $? # TODO: is this how this works in bash?
}

requireCatalystfile() {
  sourceCatalystfile \
    || echoerrandexit "Run 'catalyst project init' from project root." 1
}

requireNpmPackage() {
  findFile "${PWD}" 'package.json' PACKAGE_FILE
}

sourceWorkspaceConfig() {
  sourceFile "${PWD}" "${_WORKSPACE_CONFIG}"
  return $? # TODO: is this how this works in bash?
}

requireWorkspaceConfig() {
  sourceWorkspaceConfig \
    || echoerrandexit "Run 'catalyst workspace init' from workspace root." 1
}

yesno() {
  local PROMPT="$1"
  local DEFAULT=$2
  local HANDLE_YES=$3
  local HANDLE_NO="${4:-}" # default to noop

  local ANSWER=''
  read -p "$PROMPT" ANSWER
  if [ -z "$ANSWER" ]; then
    case "$DEFAULT" in
      Y*|y*)
        $HANDLE_YES;;
      N*|n*)
        $HANDLE_NO;;
      *)
        echo "Bad default, please answer explicitly."
        yesno "$PROMPT" "$DEFAULT" $HANDLE_YES $HANDLE_NO
    esac
  else
    case "$ANSWER" in
      Y*|y*)
        $HANDLE_YES;;
      N*|n*)
        $HANDLE_NO;;
      *)
        echo "Did not understand response, please answer 'y(es)' or 'n(o)'."
        yesno "$PROMPT" "$DEFAULT" $HANDLE_YES $HANDLE_NO
    esac
  fi
}

requireAnswer() {
  local PROMPT="$1"
  local VAR="$2"
  local DEFAULT="${3:-}"

  if [[ -n "${DEFAULT}" ]]; then
    PROMPT="${PROMPT}(${DEFAULT}) "
  fi

  while [ -z ${!VAR:-} ]; do
    read -p "$PROMPT" $VAR
    if [[ -z ${!VAR:-} ]] && [[ -z "$DEFAULT" ]]; then
      echoerr "A response is required."
    elif [[ -z ${!VAR:-} ]] && [[ -n "$DEFAULT" ]]; then
      # MacOS dosen't support 'declare -g' :(
      eval ${VAR}="${DEFAULT}"
    fi
  done
}

addLineIfNotPresentInFile() {
  local FILE="${1:-}"
  local LINE="${2:-}"
  touch "$FILE"
  grep "$LINE" "$FILE" > /dev/null || echo "$LINE" >> "$FILE"
}

updateCatalystFile() {
  local SUPPRESS_MSG="${1:-}"
  for VAR in GOPATH REL_GOAPP_PATH SQL_DIR TEST_DATA_DIR \
      CLOUDSQL_CONNECTION_NAME CLOUDSQL_CREDS CLOUDSQL_DB_DEV CLOUDSQL_DB_TEST \
      WEB_APP_DIR; do
    if [[ -n "${!VAR:-}" ]]; then
      echo "$VAR='${!VAR}'" >> "$BASE_DIR/.catalyst"
    fi
  done

  if [[ "$SUPPRESS_MSG" != 'suppress-msg' ]]; then
    echo "Updated '$BASE_DIR/.catalyst'."
  fi
}

updateProjectPubConfig() {
  PROJECT_DIR="$BASE_DIR"
  requireWorkspaceConfig
  WORKSPACE_DIR="$BASE_DIR"
  ensureWorkspaceDb
  local SUPPRESS_MSG="${1:-}"
  echo "PROJECT_HOME='$PROJECT_HOME'" > "$PROJECT_DIR/$_PROJECT_PUB_CONFIG"
  for VAR in PROJECT_MIRRORS; do
    if [[ -n "${!VAR:-}" ]]; then
      echo "$VAR='${!VAR}'" >> "$PROJECT_DIR/$_PROJECT_PUB_CONFIG"
    fi
  done

  local PROJECT_NAME=`basename $PROJECT_DIR`
  cp "$PROJECT_DIR/$_PROJECT_PUB_CONFIG" "$BASE_DIR/$_WORKSPACE_DB/projects/$PROJECT_NAME"
  if [[ "$SUPPRESS_MSG" != 'suppress-msg' ]]; then
    echo "Updated '$PROJECT_DIR/$_PROJECT_PUB_CONFIG' and '$BASE_DIR/projects/$PROJECT_NAME'."
  fi
}

# Sets up Workspace DB directory structure.
ensureWorkspaceDb() {
  cd "$WORKSPACE_DIR"
  mkdir -p "${_WORKSPACE_DB}"
  mkdir -p "${_WORKSPACE_DB}"/projects
}

requireArgs() {
  local COUNT=$#
  local I=1
  while (( $I <= $COUNT )); do
    if [[ -z ${!I:-} ]]; then
      if [[ -z $ACTION ]]; then
        echoerr "Global action '$COMPONENT' requires $COUNT additional arguments."
      else
        echoerr "'$COMPONENT $ACTION' requires $COUNT additional arguments."
      fi
      # TODO: as 'requireArgs' this should straight up exit.
      return 1
    fi
    I=$(( I + 1 ))
  done

  return 0
}

requireGlobals() {
  local COUNT=$#
  local I=1
  while (( $I <= $COUNT )); do
    local GLOBAL_NAME=${!I}
    if [[ -z ${!GLOBAL_NAME:-} ]]; then
      echoerr "'${GLOBAL_NAME}' not set. Try: 'catalyst ${COMPONENT} configure'."
      exit 1
    fi
    I=$(( I + 1 ))
  done

  return 0
}

branchName() {
  local BRANCH_DESC="${1:-}"
  requireArgs "$BRANCH_DESC" || exit $?
  echo `date +%Y-%m-%d`-`whoami`-"${BRANCH_DESC}"
}

loadCurrEnv() {
  resetEnv() {
    CURR_ENV=''
    CURR_ENV_TYPE=''
    CURR_ENV_PURPOSE=''
  }

  local PACKAGE_NAME=`cat $BASE_DIR/package.json | jq --raw-output ".name"`
  local CURR_ENV_FILE="${_CATALYST_ENVS}/${PACKAGE_NAME}/curr_env"

  if [[ -f "${CURR_ENV_FILE}" ]]; then
    source "$CURR_ENV_FILE"
  else
    resetEnv
  fi
}

_commonSelectHelper() {
  local VAR_NAME="$1"; shift
  local PRE_OPTS="$1"; shift
  local POST_OPTS="$1"; shift
  local SELECTION
  local OPTIONS="$@"
  local QUIT='false'

  while [[ $QUIT == 'false' ]]; do
    select SELECTION in $PRE_OPTS $OPTIONS $POST_OPTS; do
      case "$SELECTION" in
        '<cancel>')
          exit;;
        '<done>')
          echo "Final selection: ${!VAR_NAME}"
          QUIT='true';;
        '<other>')
          SELECTION=''
          requireAnswer "$PS3" SELECTION
          eval $VAR_NAME=\"${!VAR_NAME}'$SELECTION' \";;
        '<any>')
          echo "Final selection: 'any'"
          eval $VAR_NAME='any';;
        *)
          eval $VAR_NAME=\"${!VAR_NAME}'$SELECTION' \";;
      esac
      echo "Current selections: ${!VAR_NAME}"
      OPTIONS=${OPTIONS/$SELECTION/}
      break
    done
  done
}

selectOtherDoneCancelAny() {
  local VAR_NAME="$1"; shift
  _commonSelectHelper "$VAR_NAME" '<done> <cancel>' '<any> <other>' "$@"
}

selectOtherDoneCancel() {
  local VAR_NAME="$1"; shift
  _commonSelectHelper "$VAR_NAME" '<done> <cancel>' '<other>' "$@"
}
