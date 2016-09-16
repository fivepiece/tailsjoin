#!/bin/bash

declare -A msgs

msgs[no_run_root]='\n\tYOU SHOULD NOT RUN THIS SCRIPT AS ROOT!\n\tYOU WILL BE PROMPTED FOR THE ADMIN PASS WHEN NEEDED.\n\tPRESS ENTER TO EXIT SCRIPT, AND RUN AGAIN AS amnesia.'
msgs[script_goal_minimal]='\n\tThis script will install Joinmarket and its dependencies on a minimal tails OS without a local blockchain.\n\tYou will be using the blockr.io api for blockchain lookups (always over tor).\n\n\tPress enter to continue'
msgs[persist_on_wrong_dir]='\n\tIT SEEMS YOU HAVE PERSISTENCE ENABLED, BUT YOU ARE IN THE FOLDER:\n\n${PWD}\n\n\tIF YOU MOVE THE tailsjoin/ FOLDER TO /home/amnesia/Persistent/\n\tYOUR INSTALL WILL SURVIVE REBOOTS, OTHERWISE IT WILL NOT.\n\n\tQUIT THE SCRIPT NOW TO MOVE? (y/n) '
msgs[warn_apt_install]='\n\tInstalling dependencies:\n\n${apt_deps_jessie} ${apt_deps_testing}\n\n\tYou will be asked to input a password for sudo.'


tor_curl()
{
    curl --socks5 https://127.0.0.1:9050 -# -L --retry 5 -L -O "${1}"
}

set_global_vars()
{
    export mode_persistent=''
    export mode_full=''

    export jm_release='v0.2.1'
    export jm_home=''

    export apt_deps_jessie='gcc libc6-dev make autoconf automake libtool pkg-config libffi-dev python-dev python-pip'
    export apt_deps_testing='libsodium-dev'
}

check_root()
{
    if [[ "$(id -u)" == '0' ]]; then

        echo -e "${msgs[no_run_root]}"
        read
        exit 0
    fi
}

check_setup_sanity()
{
    echo -e "${msgs[script_goal_minimal]}"
    read
    clear
}

check_persitence()
{
    if [[ ! "${PWD}" =~ "Persistent" && -O "${HOME}/Persistent" ]]; then

        echo -e "${msgs[persist_on_wrong_dir]}"
        read q

        if [[ "${q}" =~ "Nn" ]]; then

            export mode_persistent='0'
            export jm_home="${PWD}/../"
            return
        else
            exit 0
        fi
    fi

    mode_persistent='1'
    export jm_home="${HOME}/Persistent/joinmarket/"
    clear
}

install_apt_deps()
{
    echo -e "${msgs[warn_apt_install]}"

    sudo sh -c "apt-get update && apt-get install -y ${apt_deps_jessie} && apt-get install -t testing ${apt_deps_testing}"
    
    if [[ ! check_apt_deps ]]; then

       echo "Dependencies not installed. Exiting"
       exit 0
    fi

    clear
}

check_apt_deps()
{
    dpkg -V "${apt_deps_jessie} ${apt_deps_testing}"
}

get_joinmarket_git()
{
    echo -e "Cloning joinmarket into $(dirname ${PWD})/joinmarket"
    git clone https://github.com/JoinMarket-Org/joinmarket.git ../joinmarket
    if [[ ! -z "${jm_release}" ]]; then

        echo "Checking out release ${jm_release}"
        pushd ../joinmarket
        git checkout "${jm_release}"
        popd
    fi
    clear
}
set_global_vars

