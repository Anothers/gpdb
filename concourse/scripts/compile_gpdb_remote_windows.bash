#! /bin/bash
set -eo pipefail

ROOT_DIR=`pwd`

# Get ssh private key from REMOTE_KEY, which is assumed to
# be encode in base64. We can't pass the key content directly
# since newline doesn't work well for env variable.
function setup_ssh_keys() {
    # Setup ssh keys
    echo -n $REMOTE_KEY | base64 -d > ~/remote.key
    chmod 400 ~/remote.key

    eval `ssh-agent -s`
    ssh-add ~/remote.key

    # Scan for target server's public key, append port number
    mkdir -p ~/.ssh
    ssh-keyscan -p $REMOTE_PORT $REMOTE_HOST > ~/.ssh/known_hosts
}


function remote_setup() {
    # Get a session id for different commit builds.
    SESSION_ID=`date +%Y%m%d%H%M%S.%N`

    GPDB_DIR="C:\\Users\\buildbot\\${SESSION_ID}"
    
    # Get git information from local repo(concourse gpdb_src input)
    cd gpdb_src
    GIT_URI=`git config --get remote.origin.url`
    GIT_COMMIT=`git rev-parse HEAD`
    cd ..
}

# Since we're cloning in a different machine, maybe there's 
# new commit pushed to the same repo. We need to reset to the
# same commit to current concourse build.
function remote_clone() {
    ssh -A -T -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST <<- EOF
    mkdir $GPDB_DIR
    cd $GPDB_DIR
    git clone $GIT_URI gpdb_src
    cd gpdb_src
    git reset --hard $GIT_COMMIT
EOF
}

function remote_compile() {
    # .profile is not automatically sourced when ssh -T to AIX
    ssh -T -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST <<- EOF
    cd $GPDB_DIR/gpdb_src
    set ROOT_DIR=$GPDB_DIR
    concourse\scripts\compile_gpdb_remote_windows.bat
EOF
}

function download() {
    scp -P $REMOTE_PORT -q $REMOTE_USER@$REMOTE_HOST:$GPDB_DIR/*.zip $ROOT_DIR/gpdb_artifacts/
}

# Since we are cloning and building on remote machine,
# files won't be deleted as concourse container destroys.
# We have to clean everything for success build.
function cleanup() {
    ssh -T -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST <<- EOF
    rm -rf $GPDB_DIR
EOF
}

function _main() {

    if [ -z "$REMOTE_PORT" ]; then
        REMOTE_PORT=22
    fi

    time setup_ssh_keys
    time remote_setup
    time remote_clone
    time remote_compile
    exit 1
}

_main "$@"
