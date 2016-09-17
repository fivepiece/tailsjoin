#!/bin/bash

declare -A msgs

tor_curl()
{
    curl --socks5 https://127.0.0.1:9050 -# -L --retry 5 -L -O "${1}"
}


set_global_vars()
{
    export mode_persistent=
    export mode_full="${1}"

    export jm_release="v0.2.1"
    export jm_home=

    export apt_deps_jessie="gcc libc6-dev make autoconf automake libtool pkg-config libffi-dev python-dev python-pip"
    export apt_deps_testing="libsodium-dev"
    export pip_deps="libnacl secp256k1"

    export core_url="https://bitcoin.org/bin/bitcoin-core-0.13.0/bitcoin-0.13.0-i686-pc-linux-gnu.tar.gz"
    export core_sig="https://bitcoin.org/bin/bitcoin-core-0.13.0/SHA256SUMS.asc"
    export core_key="01EA5486DE18A882D4C2684590C8019E36C2E964"
    export core_sigfile="SHA256SUMS.asc"
    export core_tarfile="bitcoin-0.13.0-i686-pc-linux-gnu.tar.gz"
    export core_home=
}


init_msgs()
{
    msgs[help_msg]="\ntailsjoin.sh - Install Joinmarket on TAILS OS >v2.3\n\n./tailsjoin.sh            -   Installs Joinmarket\n./tailsjoin.sh fullnode   -   Installs Joinmarket and gets Bitcoin Core (Persistence and ~90GB of free space required)"
    msgs[no_run_root]="\nYOU SHOULD NOT RUN THIS SCRIPT AS ROOT!\nYOU WILL BE PROMPTED FOR THE ADMIN PASS WHEN NEEDED.\nPRESS ENTER TO EXIT SCRIPT, AND RUN AGAIN AS amnesia."
    msgs[script_goal_minimal]="\nThis script will install Joinmarket and its dependencies on a minimal tails OS without a local blockchain.\nYou will be using the blockr.io api for blockchain lookups (always over tor).\n\n"
    msgs[script_goal_full]="\nThis script will install Joinmarket and its dependencies on a minimal tails OS with a local blockchain.\nThis requires both persistence and at least 90GB of free space\n\n"
    msgs[script_goal_fail]="\nFull node setup not supported without persistence.\nCreate a persistent volume with at least 90GB of free space and restart tailsjoin.sh"
    msgs[persist_on_wrong_dir]="\nIT SEEMS YOU HAVE PERSISTENCE ENABLED, BUT YOU ARE IN THE FOLDER:\n\n${PWD}\n\nIF YOU MOVE THE tailsjoin/ FOLDER TO /home/amnesia/Persistent/\nYOUR INSTALL WILL SURVIVE REBOOTS, OTHERWISE IT WILL NOT.\n\n"
    msgs[persist_mode_on]="\nPersistence is enabled and working directory is in persistent volume.\n"
    msgs[persist_mode_off]="\nPERSISTENCE IS DISABLED!\nABSOLUTELY NO DATA WILL SURVIVE A REBOOT.\n\n"
    msgs[warn_iptables]="\nApplying iptables rule:\n\niptables -I OUTPUT 2 -p tcp -s 127.0.0.1 -d 127.0.0.1 -m owner --uid-owner amnesia -j ACCEPT\n\n(needed for bitcoind rpc within the local host)\n"
    msgs[warn_apt_install]="\nInstalling dependencies:\n\napt : ${apt_deps_jessie} ${apt_deps_testing}\npip : ${pip_deps}You will be asked to input a password for sudo."
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
    if [[ "${mode_full}" == "fullnode" ]]; then

        echo -e "${msgs[script_goal_full]}"
    else

        echo -e "${msgs[script_goal_minimal]}"
    fi

    read -p "Press enter to continue or 'q' to exit. " q
    [[ "${q}" =~ [Qq] ]] && exit 0

    if [[ "${mode_full}" == "fullnode" && ! -O "${HOME}/Persistent" ]]; then

        echo -e "${msgs[script_goal_fail]}"
        exit 1
    fi
    clear
}


check_persitence()
{

    if [[ -O "${HOME}/Persistent" ]]; then

        if [[ ! "${PWD}" =~ "Persistent" ]]; then

            echo -e "${msgs[persist_on_wrong_dir]}"
            read -p "Quit the script now to move? (y/n) " q

            if [[ "${q}" =~ [Nn] ]]; then

                mode_persistent="0"
                jm_home="${PWD}/joinmarket/"
                return
            else

                exit 1
            fi
        else

            echo -e "${msgs[persist_mode_on]}"
            read -p "Continue installing Joinmarket in persistence mode? (y/n) " q

            if [[ "${q}" =~ [Yy] ]]; then

                mode_persistent='1'
                jm_home="${HOME}/Persistent/joinmarket/"
                return
            fi
        fi
    else

        echo -e "${msgs[persist_mode_off]}"
        read -p "Continue installing Joinmarket in NON-persistence mode? (y/n) " q

        if [[ "${q}" =~ [Yy] ]]; then

            mode_persistent="0"
            jm_home="${PWD}/../joinmarket/"
        else

            exit 1
        fi
    fi

    clear
}


get_joinmarket_git()
{
    echo -e "\nCloning joinmarket into ${jm_home}"
    git clone https://github.com/JoinMarket-Org/joinmarket.git "${jm_home}"
    if [[ ! -z "${jm_release}" ]]; then

        echo -e "\nChecking out release ${jm_release}"
        pushd "${jm_home}"
        git checkout "${jm_release}"
        popd
    fi
    clear
}


get_core_bitcoinorg()
{
    pushd "${HOME}/Persistent"
    echo -e "\nDownloading and verifying Bitcoin Core"

    gpg --recv-keys "${core_key}"
    echo "${core_key}:6" | gpg --import-ownertrust -

    tor_curl "${core_url}"
    tor_curl "${core_sig}"

    gpg --verify "${core_sigfile}"

    if [[ "$?" != "0" ]]; then

        echo -e "\nSIGNATURE VERIFICATION FAILED !"
        rm -rf "${core_tarfile}" "${core_sigfile}"
        clear

        read -p "Retry? (y/n)" q

        if [[ "${q}" =~ [Nn] ]]; then

            echo -e "\nExiting." && exit 1
        else
            get_core_bitcoinorg
        fi
    fi

    tar xzvf "${core_tarfile}"
    core_home="${PWD}/${core_tarfile/-i686-pc-linux-gnu.tar.gz/}"
    popd
}


make_core_cfg()
{
    if [[ -e "${core_home}/bin/bitcoin.conf" ]]; then

        echo -e "\nFile bitcoin.conf found in ${core_home}/bin/."
        read -p "Overwrite? (y/n) " q

        [[ "${q}" =~ [Nn] ]] && return
    fi

# initentionally not indented
    cat << ENDCORECFG > "${core_home}/bin/bitcoin.conf"
rpcuser="$(pwgen -ncsB 35 1)"
rpcpassword="$(pwgen -ncsB 75 1)"
daemon=1
proxyrandomize=1
proxy=127.0.0.1:9050
listen=0
server=1

# For JoinMarket
walletnotify=curl -sI --connect-timeout 1 http://127.0.0.1:62602/walletnotify?%s
alertnotify=curl -sI --connect-timeout 1 http://127.0.0.1:62602/alertnotify?%s

# Uncomment and fill in a persistent full path for the blockchain datadir
#datadir=${core_home}/data
ENDCORECFG

    mkdir -p "${core_home}/data"
}

install_deps()
{
    if [[ "${mode_full}" == "fullnode" ]]; then

        echo -e "${msgs[warn_iptables]}"
    fi

    check_deps 2>/dev/null && return

    echo -e "${msgs[warn_apt_install]}"

    sudo bash -c "apt-get update && apt-get install -y ${apt_deps_jessie} && apt-get install -y -t testing ${apt_deps_testing}; \
                if [[ $? == 0 ]]; then \
                    torify pip install -r ${jm_home}/requirements.txt && chmod -R ugo+rX /usr/local/lib/python2.7/dist-packages/; \
                fi; \
                if [[ ${mode_full} == 'fullnode' && $? == 0 ]]; then \
                    iptables -I OUTPUT 2 -p tcp -s 127.0.0.1 -d 127.0.0.1 -m owner --uid-owner amnesia -j ACCEPT; \
                fi; \
                if [[ $? != 0 ]]; then \
                    echo '\n\nFAILED TO APPLY IPTABLES RULE FOR BITCOIND RPC\nSetup will continue, but full node functionality\n with Joinmarket will not work.'; \
                fi;"
    
    if ! check_deps 2>/dev/null; then

       echo -e "\nDependencies not installed. Exiting"
       exit 1
    fi

    clear
}


check_deps()
{
    if (( "$(apt-cache policy ${apt_deps_jessie} ${apt_deps_testing} | grep -c 'Installed: (none)')" )); then

        return 1
    fi

    for pylib in ${pip_deps}; do

        if ! python -c "import ${pylib}"; then

            return 1
        fi
    done

    return 0
}


# initentionally not indented
make_jm_cfg()
{
    cat << ENDJMCFG > "${jm_home}/joinmarket.cfg"
# Set JoinMarket config for tor and blockr. 
[BLOCKCHAIN]
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
    set_global_vars "${1}"
    init_msgs
    if [[ "${1}" =~ -[-h] ]]; then

        echo -e "${msgs[help_msg]}"
        exit 0
    fi

    clear
    check_root
    check_setup_sanity
    check_persitence
    get_joinmarket_git
    install_deps
    check_deps
    make_jm_cfg
    if [[ "${mode_full}" == "fullnode" ]]; then
        get_core_bitcoinorg
        make_core_cfg
    fi
    clear

    echo -e "\nJoinmarket installed in: ${jm_home}"
    cd "${jm_home}"
}

main "${1}"
exit 0
