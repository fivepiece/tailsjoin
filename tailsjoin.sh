#!/bin/bash

tor_curl()
{
    curl -x https://127.0.0.1:9050 -# -L --retry 5 -L "${1}" -O "${2}"
}

set_global_vars()
{
    export mode_persistent=''
    export mode_full=''

    export jm_release=''

    export libsodium_url='https://download.libsodium.org/libsodium/releases'
    export libsodium_rel='libsodium-1.0.11'
    export libsodium_key='54A2B8892CC3D6A597B92B6C210627AABA709FE1'

    export libnacl_url='https://github.com/saltstack/libnacl/archive'
    export libnacl_rel='v1.5.0'

    export secp256k1_url=''
    export secp256k1_rel=''
}

check_root()
{
    if [[ "$(id -u)" == '0' ]]; then

        echo -e "\
            YOU SHOULD NOT RUN THIS SCRIPT AS ROOT!\n \
            YOU WILL BE PROMPTED FOR THE ADMIN PASS WHEN NEEDED."

        read -p "PRESS ENTER TO EXIT SCRIPT, AND RUN AGAIN AS amnesia. "
        exit 0
    fi
}

check_setup_sanity()
{
    echo -e "\
        THIS SCRIPT WILL INSTALL JOINMARKET AND ITS DEPENDENCIES ON\n \
        A MINIMAL TAILS OS WITHOUT A LOCAL BLOCKCHAIN. YOU WILL BE\n \
        USING THE BLOCKR.IO API FOR BLOCKCHAIN LOOKUPS (ALWAYS OVER TOR)."

    read -p "PRESS ENTER TO CONTINUE "
    clear
}

check_persitence()
{
    if [[ ! "${PWD}" =~ "Persistent" && -O "${HOME}/Persistent" ]]; then

        echo -e "\
            IT SEEMS YOU HAVE PERSISTENCE ENABLED, BUT YOU ARE IN THE FOLDER:\n \
            ${PWD} \n \
            IF YOU MOVE THE tailsjoin/ FOLDER TO /home/amnesia/Persistent/ \n \
            YOUR INSTALL WILL SURVIVE REBOOTS, OTHERWISE IT WILL NOT."

        read -p "QUIT THE SCRIPT NOW TO MOVE? (y/n) " q
        if [[ "${q}" =~ "Nn" ]]; then

            mode_persistent='0'
            jm_home="${PWD}/../"
            return
        else
            exit 0
        fi

        mode_persistent='1'
        jm_home="${HOME}/Persistent/joinmarket/"
        clear
    fi
}

install_libsodium_deps()
{
    echo -e "\
        ENTER PASSWORD TO INSTALL: 'gcc', 'libc6-dev', and 'make'\n \
        (NEEDED TO BUILD LIBSODIUM CRYPTO LIBRARY)"

    sudo sh -c 'apt-get update && apt-get install -y gcc libc6-dev make python-pip'

    check_libsodium_deps || echo "Dependencies not installed. Exiting" && exit 0

    clear
}

check_libsodium_deps()
{
    dpkg -V libc6-dev make gcc
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

get_libnacl()
{
    tor_curl "${libnacl_url}/${libnacl_rel}.tar.gz" "${libnack_rel}.tar.gz"
}

extract_libnacl()
{
    tar xzvf "${libnacl_rel}.tar.gz"
    rm "${libnacl_rel}.tar.gz"
}

install_libnacl()
{
    pushd "${libnacl_rel}"
    sed -i "s|/usr/local/lib|${jm_home}/libsodium|" ./libnacl/__init.py && echo "sed -i on __init__.py @ install_libnacl good"

    mv ./libnacl "${jm_home}/"
}

get_libsodium_keys()
{
    echo "Getting libsodium PGP keys"
    gpg --recv-keys "${libsodium_key}"
    echo "${libsodium_key}:6" | gpg --import-ownertrust -
    clear
}

get_libsodium()
{
    echo "DOWNLOADING LIBSODIUM SOURCE AND SIGNING KEY..."

    tor_curl "${libsodium_url}/${libsodium_rel}.sig" "${libsodium_rel}.sig"
    tor_curl "${libsodium_url}/${libsodium_rel}.tar.gz" "${libsodium_rel}.tar.gz"

    clear
}

verify_libsodium()
{
    echo "VERIFYING THE DOWNLOAD..."
    false || gpg --verify "${libsodium_rel}.sig" "${libsodium_rel}.tar.gz"

    if [[ "$?" != '0' ]]; then

        echo -e "BAD SIGNATURE.\n SECURELY DELETING FILES AND DOWNLOADING AGAIN..."
        srm -drv "${libsodium_rel}" "${libsodium_rel}.sig"
        get_libsodium

        false || gpg --verify "${libsodium_rel}.sig" "${libsodium_rel}.tar.gz"

        [[ "$?" != '0' ]] && echo "BAD SIGNATURE. ABORTING." && exit 1

    fi

    echo "VERIFY OK"
    clear
}

extract_libsodium()
{
    tar xzvf "${libsodium_rel}"
    rm "${libsodium_rel}.tar.gz" "${libsodium_rel}.sig"
    clear
}

build_libsodium()
{
    local conf_opts

    if (( "${mode_persistence}" )); then

        conf_opts="--prefix=${PWD}/${libsodium_rel}"
    fi

    pushd "${libsodium_rel}"
    ./configure "${conf_opts}"
    make
    popd
}

install_libsodium()
{
    if (( "${mode_persistence}" )); then

        mkdir -p ../joinmarket/libsodium
        cp "${libsodium_rel}/lib/libsodium.*" ../joinmarket/libsodium

        pushd ../joinmarket
        git commit -a -m "Tailsjoin survive reboots"
        popd
    else

        pushd "${joinmarket_rel}"
        sudo make install
        popd
    fi

    rm -rf "${libsodium_rel}"
    clear
}

set_global_vars

