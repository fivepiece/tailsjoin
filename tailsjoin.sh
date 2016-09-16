#!/bin/bash

declare -A msgs

tor_curl()
{
    curl --socks5 https://127.0.0.1:9050 -# -L --retry 5 -L -O "${1}"
}


set_global_vars()
{
    export mode_persistent=
    export mode_full=

    export jm_release="v0.2.1"
    export jm_home=

    export apt_deps_jessie="gcc libc6-dev make autoconf automake libtool pkg-config libffi-dev python-dev python-pip"
    export apt_deps_testing="libsodium-dev"
    export pip_deps="libnacl secp256k1"
}


init_msgs()
{
    msgs[no_run_root]="\n\tYOU SHOULD NOT RUN THIS SCRIPT AS ROOT!\n\tYOU WILL BE PROMPTED FOR THE ADMIN PASS WHEN NEEDED.\n\tPRESS ENTER TO EXIT SCRIPT, AND RUN AGAIN AS amnesia."
    msgs[script_goal_minimal]="\n\tThis script will install Joinmarket and its dependencies on a minimal tails OS without a local blockchain.\n\tYou will be using the blockr.io api for blockchain lookups (always over tor).\n\n\tPress enter to continue"
    msgs[persist_on_wrong_dir]="\n\tIT SEEMS YOU HAVE PERSISTENCE ENABLED, BUT YOU ARE IN THE FOLDER:\n\n${PWD}\n\n\tIF YOU MOVE THE tailsjoin/ FOLDER TO /home/amnesia/Persistent/\n\tYOUR INSTALL WILL SURVIVE REBOOTS, OTHERWISE IT WILL NOT.\n\n\tQUIT THE SCRIPT NOW TO MOVE? (y/n) "
    msgs[warn_apt_install]="\n\tInstalling dependencies:\n\n${apt_deps_jessie} ${apt_deps_testing} ${pip_deps}\n\n\tYou will be asked to input a password for sudo."
}


check_root()
{
    if [[ "$(id -u)" == "0" ]]; then

        echo -e "${msgs[no_run_root]}"
        read
        exit 1
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

            mode_persistent='0'
            jm_home="${PWD}/../"
            return
        else
            exit 1
        fi
    fi

    mode_persistent='1'
    jm_home="${HOME}/Persistent/joinmarket/"
    clear
}


get_joinmarket_git()
{
    echo -e "Cloning joinmarket into ${jm_home}"
    git clone https://github.com/JoinMarket-Org/joinmarket.git "${jm_home}"
    if [[ ! -z "${jm_release}" ]]; then

        echo "Checking out release ${jm_release}"
        pushd "${jm_home}"
        git checkout "${jm_release}"
        popd
    fi
    clear
}


install_deps()
{
    echo -e "${msgs[warn_apt_install]}"

    sudo sh -c "apt-get update && apt-get install -y ${apt_deps_jessie} && apt-get install -y -t testing ${apt_deps_testing}; \
                torify pip install -r ${jm_home}/requirements.txt && chmod -R ugo+rX /usr/local/lib/python2.7/dist-packages/"
    
    if [[ ! check_deps ]]; then

       echo "Dependencies not installed. Exiting"
       exit 1
    fi

    clear
}


check_deps()
{
    dpkg -V ${apt_deps_jessie} ${apt_deps_testing} && pip show ${pip_deps} 2>/dev/null
}


make_jm_cfg() # initentionally not indented
{
cat << ENDJMCFG > "${jm_home}/joinmarket.cfg"
# Set JoinMarket config for tor and blockr. 
echo "[BLOCKCHAIN]
blockchain_source = blockr
# blockchain_source options: blockr, bitcoin-rpc, json-rpc, regtest 
# for instructions on bitcoin-rpc read https://github.com/chris-belcher/joinmarket/wiki/Running-JoinMarket-with-Bitcoin-Core-full-node
network = mainnet
rpc_host = localhost
rpc_port = 8332
rpc_user = bitcoin
rpc_password = password

[MESSAGING] 
#host = irc.cyberguerrilla.org
channel = joinmarket-pit
port = 6697 
usessl = true 
socks5 = false
socks5_host = localhost 
socks5_port = 9050
# for tor 
host = 6dvj6v5imhny3anf.onion 
# The host below is an alternative if the above isn't working.
#host = a2jutl5hpza43yog.onion
maker_timeout_sec = 60

[POLICY]
# merge_algorithm options: greedy, default, gradual 
merge_algorithm = default
ENDJMCFG
}

main()
{
    clear
    set_global_vars
    init_msgs
    check_root
    check_setup_sanity
    check_persitence
    get_joinmarket_git
    install_deps
    check_deps
    make_jm_cfg
    clear
}

main
echo "Joinmarket installed in: ${jm_home}"
exit 0
