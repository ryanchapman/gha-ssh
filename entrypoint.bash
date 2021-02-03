#!/bin/bash -

set -o pipefail

TRUE=0
FALSE=1

BOLD=""
CLR=""
RED=""
GREEN=""
CYAN=""

function usage
{
  echo 'usage in your GitHub action: '
  echo
  echo 'steps:'
  echo '- name: ssh'
  echo '  uses: ryanchapman/gha-ssh@v1'
  echo '  timeout-minutes: 10'
  echo '  with:'
  echo "    authorized_github_users: 'johndoe,janedoe'"
  echo '    debug: <true|false>'
  echo
  echo
  echo 'example yml file:'
  echo '-----------------'
  echo
  echo 'name: continuous deployment'
  echo 'on:'
  echo ' push'
  echo
  echo 'jobs:'
  echo '  deploy:'
  echo '    runs-on: ubuntu-latest'
  echo '    steps:'
  echo '    - name: ssh'
  echo '      uses: ryanchapman/gha-ssh@v1'
  echo '      # after the container starts tmate in the background, it will'
  echo '      # sleep for 24 hours, so it is important that you set a timeout here'
  echo '      # so that you do not run up your GitHub Actions bill'
  echo '      timeout-minutes: 10'
  echo '      with:'
  echo '        # authorized_github_users: required'
  echo '        # list of GitHub users who should be allowed to ssh into container'
  echo '        # on gha-ssh container start, it downloads the ssh public key for each'
  echo '        # user from GitHub and places it in ~/authorized_keys'
  echo '        # tmate is started with `-a ~/authorized_keys` to only allow access'
  echo '        # to those ssh keys'
  echo "        authorized_github_users: 'johndoe,janedoe'"
  echo '        # debug: optional'
  echo '        # defaults to `false` if not set here'
  echo '        # if debug is set, then tmate is started with `-vvv -F`'
  echo '        debug: true'
}

function log
{
    if [[ "${1}" == "FATAL" ]]; then
        fatal="FATAL"
        shift
    fi
    echo -n "$(date '+%b %d %H:%M:%S.%N %Z') $(basename -- $0)[$$]: "
    if [[ "${fatal}" == "FATAL" ]]; then echo -n "${RED}${fatal} "; fi
    echo "$*"
    if [[ "${fatal}" == "FATAL" ]]; then echo -n "${CLR}"; echo; usage; exit 1; fi
}

function run_ignerr
{
    _run warn $*
}

function run
{
    _run fatal $*
}

function _run
{
    if [[ $1 == fatal ]]; then
        errors_fatal=$TRUE
    else
        errors_fatal=$FALSE
    fi
    shift
    log "${BOLD}$*${CLR}"
    eval "$*"
    rc=$?
    if [[ $rc != 0 ]]; then
        msg="${BOLD}${RED}$*${CLR}${RED} returned $rc${CLR}"
    else
        msg="${BOLD}${GREEN}$*${CLR}${GREEN} returned $rc${CLR}"
    fi
    log "$msg"
    # fail hard and fast
    if [[ $rc != 0 && $errors_fatal == $TRUE ]]; then
        pwd
        exit 1
    fi
    return $rc
}

function generate_authorized_keys
{
  local u=""
  if [[ "${INPUT_AUTHORIZED_GITHUB_USERS}" == "" ]]; then
    log FATAL "authorized_github_users must be specified as an input to this GitHub Action"
  fi
  log "INPUT_AUTHORIZED_GITHUB_USERS=\"${INPUT_AUTHORIZED_GITHUB_USERS}\""
  for u in $(echo "${INPUT_AUTHORIZED_GITHUB_USERS}" | tr -d ' ' | tr ',' ' '); do
    log "Getting ssh keys for GitHub user ${u}"
    local ukeys="$(curl -sL https://github.com/${u}.keys)"
    log "Getting ssh keys for GitHub user ${u}: ${ukeys}"

    # TODO(rchapman): check validity of each ssh key. For now, assume if
    #                 the first key starts with "ssh-" then GitHub returned
    #                 us a good list of ssh keys.
    if [[ ! "${ukeys}" =~ ^ssh- ]]; then
      log FATAL "ssh keys for user ${u} do not begin with \"ssh-\", got \"${ukeys}\""
    fi

    log "Adding ssh keys for GitHub user ${u} to ~/authorized_keys"
    echo "${ukeys}" >> ~/authorized_keys
    log "Adding ssh keys for GitHub user ${u} to ~/authorized_keys: done"
  done
}

function main
{
  log "Generating new ssh host keys"
  if ls /etc/ssh/ssh_host_* &>/dev/null; then
    run rm -v /etc/ssh/ssh_host_*
  fi
  run dpkg-reconfigure openssh-server
  log "Generating new ssh host keys: done"

  log "Generating new ssh keypair for $(whoami)"
  if ls ~/.ssh/id_rsa* &>/dev/null; then
    run rm -v ~/.ssh/id_rsa*
  fi
  run "mkdir -p ~/.ssh"
  run "ssh-keygen -t rsa -f ~/.ssh/id_rsa -N \"\" -q"
  log "Generating new ssh keypair for $(whoami): done"

  log "Generating ~/authorized_keys"
  generate_authorized_keys
  log "Generating ~/authorized_keys: done"

  log "Checking if debugging is enabled"
  if [[ "${INPUT_DEBUG}" == "true" ]]; then
    opts_debug="-vvv -F"
    opts_daemon=""
    log "Checking if debugging is enabled: yes"
  else
    opts_debug=""
    opts_daemon="-d"
    log "Checking if debugging is enabled: no (INPUT_DEBUG=\"${INPUT_DEBUG}\")"
  fi

  log "Creating new tmate session"
  log "tmate version:"
  run tmate -V
  run tmate ${opts_debug} -S /tmp/tmate.sock -a ~/authorized_keys new-session ${opts_daemon}
  run "tmate -S /tmp/tmate.sock wait tmate-ready"
  log "Creating new tmate session: done"

  echo "Connect to:"
  tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}'

  # we rely on GitHub Action parameter `timeout-minutes` to kill before 24h
  run sleep 24h
}

main $*
