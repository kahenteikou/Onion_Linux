#!/usr/bin/env bash
#
# Yamada Hayao
# Twitter: @Hayao0819
# Email  : hayao@fascode.net
#
# (c) 2019-2021 Fascode Network.
#
# build.sh
#
# The main script that runs the build
#

set -e
script_path="$( cd -P "$( dirname "$(readlink -f "$0")" )" && cd .. && pwd )"
module_dir="${script_path}/modules"
alteriso_version="3.1"

_help() {
    echo "usage ${0} [options] [command]"
    echo
    echo "Scripts that perform operations related to modules" 
    echo
    echo " General command:"
    echo "    check [name]              Determine if the locale is available"
    echo "    show                      Shows a list of available modules"
    echo "    depend [name]             Shows the modules that the module depends on"
    echo "    help                      This help message"
    echo
    echo " General options:"
    echo "    -v | --version [ver]      Specifies the AlterISO version"
    echo "    -h | --help               This help message"
}

check(){
    if (( "${#}" == 0 )) || (( "${#}" >= 2 ));then
        _help
        exit 1
    fi
    local _version
    if [[ -f "${module_dir}/${1}/alteriso" ]]; then
        _version="$(
            source "${module_dir}/${1}/alteriso"
            echo "${alteriso}"
            unset alteriso
        )"
        if (( "$(echo "${_version}" | cut -d "." -f 1)" == "$(echo "${alteriso_version}" | cut -d "." -f 1)" )); then
            echo "correct"
        fi
    else
        echo "incorrect"
    fi
}

depend(){
    if (( "${#}" == 0 )) || (( "${#}" >= 2 ));then
        _help
        exit 1
    fi
    if [[ ! "$(check "${1}")" = "correct" ]]; then
        exit 1
    elif [[ ! -f "${module_dir}/${1}/dependent" ]]; then
        exit 0
    else
        printf "%s\n" $(grep -h -v ^'#' "${module_dir}/${1}/dependent") | tr "\n" " "
        echo
        exit 0
    fi
}

show(){
    local _module _name _version _list=()
    while read -r _module; do
        _name="$(basename "$(dirname "${_module}")")"
        _version="$(
            source "${_module}"
            echo "${alteriso}"
            unset alteriso
        )"
        if (( "$(echo "${_version}" | cut -d "." -f 1)" == "$(echo "${alteriso_version}" | cut -d "." -f 1)" )); then
            _list+=("${_name}")
        else
            continue
        fi
    done < <(find "${module_dir}" -maxdepth 2 -mindepth 2 -type f -name "alteriso")
    echo "${_list[@]}"
}

# Parse options
ARGUMENT="${@}"
OPTS="hv:"
OPTL="help,version:"
if ! OPT=$(getopt -o ${OPTS} -l ${OPTL} -- ${ARGUMENT}); then
    exit 1
fi

eval set -- "${OPT}"
unset OPT OPTL OPTS

while true; do
    case "${1}" in
        -h | --help)
            _help
            exit 0
            ;;
        -v | --version)
            alteriso_version="${2}"
            shift 2
            ;;
        --)
            shift 1
            break
            ;;

    esac
done

if [[ -z "${1}" ]]; then
    _help
    exit 1
else
    COMMAND="${1}"
    shift 1
fi

case "${COMMAND}" in
    "check" ) check "${@}"  ;;
    "depend") depend "${@}" ;;
    "show"  ) show          ;;
    "help"  ) _help; exit 0 ;;
    *       ) _help; exit 1 ;;
esac
