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

set -eu

# Internal config
# Do not change these values.
script_path="$( cd -P "$( dirname "$(readlink -f "${0}")" )" && pwd )"
defaultconfig="${script_path}/default.conf"
tools_dir="${script_path}/tools"
module_dir="${script_path}/modules"
customized_username=false
customized_password=false
customized_kernel=false
DEFAULT_ARGUMENT=""
alteriso_version="3.1"

# Load config file
if [[ -f "${defaultconfig}" ]]; then
    source "${defaultconfig}"
else
    "${tools_dir}/msg.sh" -a 'build.sh' error "${defaultconfig} was not found."
    exit 1
fi

# Load custom.conf
if [[ -f "${script_path}/custom.conf" ]]; then
    source "${script_path}/custom.conf"
fi

umask 0022

# Show an INFO message
# ${1}: message string
msg_info() {
    local _msg_opts="-a build.sh"
    if [[ "${1}" = "-n" ]]; then
        _msg_opts="${_msg_opts} -o -n"
        shift 1
    fi
    [[ "${msgdebug}" = true ]] && _msg_opts="${_msg_opts} -x"
    [[ "${nocolor}"  = true ]] && _msg_opts="${_msg_opts} -n"
    "${tools_dir}/msg.sh" ${_msg_opts} info "${1}"
}

# Show an Warning message
# ${1}: message string
msg_warn() {
    local _msg_opts="-a build.sh"
    if [[ "${1}" = "-n" ]]; then
        _msg_opts="${_msg_opts} -o -n"
        shift 1
    fi
    [[ "${msgdebug}" = true ]] && _msg_opts="${_msg_opts} -x"
    [[ "${nocolor}"  = true ]] && _msg_opts="${_msg_opts} -n"
    "${tools_dir}/msg.sh" ${_msg_opts} warn "${1}"
}

# Show an debug message
# ${1}: message string
msg_debug() {
    if [[ "${debug}" = true ]]; then
        local _msg_opts="-a build.sh"
        if [[ "${1}" = "-n" ]]; then
            _msg_opts="${_msg_opts} -o -n"
            shift 1
        fi
        [[ "${msgdebug}" = true ]] && _msg_opts="${_msg_opts} -x"
        [[ "${nocolor}"  = true ]] && _msg_opts="${_msg_opts} -n"
        "${tools_dir}/msg.sh" ${_msg_opts} debug "${1}"
    fi
}

# Show an ERROR message then exit with status
# ${1}: message string
# ${2}: exit code number (with 0 does not exit)
msg_error() {
    local _msg_opts="-a build.sh"
    if [[ "${1}" = "-n" ]]; then
        _msg_opts="${_msg_opts} -o -n"
        shift 1
    fi
    [[ "${msgdebug}" = true ]] && _msg_opts="${_msg_opts} -x"
    [[ "${nocolor}"  = true ]] && _msg_opts="${_msg_opts} -n"
    "${tools_dir}/msg.sh" ${_msg_opts} error "${1}"
    if [[ -n "${2:-}" ]]; then
        exit ${2}
    fi
}


# Usage: getclm <number>
# 標準入力から値を受けとり、引数で指定された列を抽出します。
getclm() {
    echo "$(cat -)" | cut -d " " -f "${1}"
}

# Usage: echo_blank <number>
# 指定されたぶんの半角空白文字を出力します
echo_blank(){
    yes " " | head -n "${1}" | tr -d "\n"
}

_usage () {
    echo "usage ${0} [options] [channel]"
    echo
    echo "A channel is a profile of AlterISO settings."
    echo
    echo " General options:"
    echo "    -b | --boot-splash           Enable boot splash"
    echo "    -e | --cleanup | --cleaning  Enable post-build cleaning"
    echo "         --tarball               Build rootfs in tar.xz format"
    echo "    -h | --help                  This help message and exit"
    echo
    echo "    -a | --arch <arch>           Set iso architecture"
    echo "                                  Default: ${arch}"
    echo "    -c | --comp-type <comp_type> Set SquashFS compression type (gzip, lzma, lzo, xz, zstd)"
    echo "                                  Default: ${sfs_comp}"
    echo "    -g | --gpgkey <key>          Set gpg key"
    echo "                                  Default: ${gpg_key}"
    echo "    -l | --lang <lang>           Specifies the default language for the live environment"
    echo "                                  Default: ${locale_name}"
    echo "    -k | --kernel <kernel>       Set special kernel type.See below for available kernels"
    echo "                                  Default: ${defaultkernel}"
    echo "    -o | --out <out_dir>         Set the output directory"
    echo "                                  Default: ${out_dir}"
    echo "    -p | --password <password>   Set a live user password"
    echo "                                  Default: ${password}"
    echo "    -t | --comp-opts <options>   Set compressor-specific options."
    echo "                                  Default: empty"
    echo "    -u | --user <username>       Set user name"
    echo "                                  Default: ${username}"
    echo "    -w | --work <work_dir>       Set the working directory"
    echo "                                  Default: ${work_dir}"
    echo

    local blank="33" _arch  _list _dirname

    echo " Language for each architecture:"
    for _list in ${script_path}/system/locale-* ; do
        _arch="${_list#${script_path}/system/locale-}"
        echo -n "    ${_arch}"
        echo_blank "$(( ${blank} - 4 - ${#_arch} ))"
        "${tools_dir}/locale.sh" -a "${_arch}" show
    done

    echo
    echo " Kernel for each architecture:"
    for _list in ${script_path}/system/kernel-* ; do
        _arch="${_list#${script_path}/system/kernel-}"
        echo -n "    ${_arch} "
        echo_blank "$(( ${blank} - 5 - ${#_arch} ))"
        "${tools_dir}/kernel.sh" -a "${_arch}" show
    done

    echo
    echo " Channel:"
    for _dirname in $(bash "${tools_dir}/channel.sh" --version "${alteriso_version}" -d -b -n show); do
        echo -ne "    ${_dirname%.add}"
        echo_blank "$(( ${blank} - 3 - $(echo ${_dirname%.add} | wc -m) ))"
        "${tools_dir}/channel.sh" --version "${alteriso_version}" --nocheck desc "${_dirname%.add}"
    done

    echo
    echo " Debug options: Please use at your own risk."
    echo "    -d | --debug                 Enable debug messages"
    echo "    -x | --bash-debug            Enable bash debug mode(set -xv)"
    echo "         --channellist           Output the channel list and exit"
    echo "         --gitversion            Add Git commit hash to image file version"
    echo "         --msgdebug              Enables output debugging"
    echo "         --noaur                 Ignore aur packages (Use only for debugging)"
    echo "         --nocolor               No output colored output"
    echo "         --noconfirm             No check the settings before building"
    echo "         --nochkver              No check the version of the channel"
    echo "         --nodebug               No debug message"
    echo "         --noefi                 No efi boot (Use only for debugging)"
    echo "         --noloopmod             No check and load kernel module automatically"
    echo "         --nodepend              No check package dependencies before building"
    echo "         --noiso                 No build iso image (Use with --tarball)"
    echo "         --normwork              No remove working dir"
    echo
    echo " Many packages are installed from AUR, so specifying --noaur can cause problems."
    echo
    if [[ -n "${1:-}" ]]; then exit "${1}"; fi
}

# Unmount helper Usage: _umount <target>
_umount() { if mountpoint -q "${1}"; then umount -lf "${1}"; fi; }

# Mount helper Usage: _mount <source> <target>
_mount() { if ! mountpoint -q "${2}" && [[ -f "${1}" ]] && [[ -d "${2}" ]]; then mount "${1}" "${2}"; fi; }

# Unmount chroot dir
umount_chroot () {
    local _mount
    for _mount in $(cat /proc/mounts | getclm 2 | grep $(realpath ${work_dir}) | tac); do
        if [[ ! "${_mount}" = "$(realpath ${work_dir})/${arch}/airootfs" ]]; then
            msg_info "Unmounting ${_mount}"
            _umount "${_mount}" 2> /dev/null
        fi
    done
}

# Mount airootfs on "${work_dir}/${arch}/airootfs"
mount_airootfs () {
    mkdir -p "${airootfs_dir}"
    _mount "${airootfs_dir}.img" "${airootfs_dir}"
}

umount_airootfs() {
    if [[ -v airootfs_dir ]]; then _umount "${airootfs_dir}"; fi
}

umount_chroot_advance() {
    umount_chroot
    umount_airootfs
}

# Helper function to run make_*() only one time.
run_once() {
    set -eu
    if [[ ! -e "${work_dir}/build.${1}_${arch}" ]]; then
        msg_debug "Running ${1} ..."
        mount_airootfs
        "${1}"
        touch "${work_dir}/build.${1}_${arch}"
        umount_chroot_advance
    else
        msg_debug "Skipped because ${1} has already been executed."
    fi
}

# Show message when file is removed
# remove <file> <file> ...
remove() {
    local _file
    for _file in "${@}"; do msg_debug "Removing ${_file}"; rm -rf "${_file}"; done
}

# 強制終了時にアンマウント
umount_trap() {
    local _status="${?}"
    umount_chroot_advance
    msg_error "It was killed by the user.\nThe process may not have completed successfully."
    exit "${_status}"
}

# 設定ファイルを読み込む
# load_config [file1] [file2] ...
load_config() {
    local _file
    for _file in ${@}; do if [[ -f "${_file}" ]] ; then source "${_file}" && msg_debug "The settings have been overwritten by the ${_file}"; fi; done
}

# Display channel list
show_channel_list() {
    if [[ "${nochkver}" = true ]]; then
        bash "${tools_dir}/channel.sh" -v "${alteriso_version}" -n show
    else
        bash "${tools_dir}/channel.sh" -v "${alteriso_version}" show
    fi
}

# Execute command for each module. It will be executed with {} replaced with the module name.
# for_module <command>
for_module(){
    local module
    for module in ${modules[@]}; do eval $(echo ${@} | sed "s|{}|${module}|g"); done
}

# パッケージをインストールする
_pacman(){
    msg_info "Installing packages to ${airootfs_dir}/'..."
    pacstrap -C "${work_dir}/pacman-${arch}.conf" -c -G -M -- "${airootfs_dir}" ${*}
    msg_info "Packages installed successfully!"
}

# コマンドをchrootで実行する
_chroot_run() {
    msg_debug "Run command in chroot\nCommand: ${*}"
    eval -- arch-chroot "${airootfs_dir}" ${@}
}

_cleanup_common () {
    msg_info "Cleaning up what we can on airootfs..."

    # Delete pacman database sync cache files (*.tar.gz)
    [[ -d "${airootfs_dir}/var/lib/pacman" ]] && find "${airootfs_dir}/var/lib/pacman" -maxdepth 1 -type f -delete
    # Delete pacman database sync cache
    [[ -d "${airootfs_dir}/var/lib/pacman/sync" ]] && find "${airootfs_dir}/var/lib/pacman/sync" -delete
    # Delete pacman package cache
    [[ -d "${airootfs_dir}/var/cache/pacman/pkg" ]] && find "${airootfs_dir}/var/cache/pacman/pkg" -type f -delete
    # Delete all log files, keeps empty dirs.
    [[ -d "${airootfs_dir}/var/log" ]] && find "${airootfs_dir}/var/log" -type f -delete
    # Delete all temporary files and dirs
    [[ -d "${airootfs_dir}/var/tmp" ]] && find "${airootfs_dir}/var/tmp" -mindepth 1 -delete
    # Delete package pacman related files.
    find "${work_dir}" \( -name '*.pacnew' -o -name '*.pacsave' -o -name '*.pacorig' \) -delete

    # Create an empty /etc/machine-id
    printf '' > "${airootfs_dir}/etc/machine-id"

    msg_info "Done!"
}

_cleanup_airootfs(){
    _cleanup_common

    # Delete all files in /boot
    [[ -d "${airootfs_dir}/boot" ]] && find "${airootfs_dir}/boot" -mindepth 1 -delete
}

_mkchecksum() {
    local name="${1}"
    cd -- "${out_dir}"
    msg_info "Creating md5 checksum ..."
    md5sum "${1}" > "${1}.md5"
    msg_info "Creating sha256 checksum ..."
    sha256sum "${1}" > "${1}.sha256"
    cd -- "${OLDPWD}"
}

# Check the value of a variable that can only be set to true or false.
check_bool() {
    local _value _variable
    for _variable in ${@}; do
        msg_debug -n "Checking ${_variable}..."
        eval ': ${'${_variable}':=""}'
        _value="$(eval echo '$'${_variable})"
        if [[ ! -v "${1}" ]] || [[ "${_value}"  = "" ]]; then
            if [[ "${debug}" = true ]]; then echo; fi; msg_error "The variable name ${_variable} is empty." "1"
        fi
        if [[ ! "${_value}" = "true" ]] && [[ ! "${_value}" = "false" ]]; then
            if [[ "${debug}" = true ]]; then echo; fi; msg_error "The variable name ${_variable} is not of bool type." "1"
        elif [[ "${debug}" = true ]]; then
            echo -e " ${_value}"
        fi
    done
}


# Check the build environment and create a directory.
prepare_env() {
    # Check packages
    if [[ "${nodepend}" = false ]]; then
        local _check_failed=false _pkg _result=0 _version _local _latest
        msg_info "Checking dependencies ..."
        for _pkg in ${dependence[@]}; do
            msg_debug -n "Checking ${_pkg} ..."
            _version="$("${tools_dir}/package.py" -s "${_pkg}")" || _result="${?}"
            case "${_result}" in
                "0")
                    [[ "${debug}" = true ]] && echo -ne " ${_version}\n"
                    ;;
                "1")
                    echo; msg_warn "Failed to get the latest version of ${_pkg}."
                    ;;
                "2")
                    _local="$(echo "${_version}" | getclm 1)"
                    _latest="$(echo "${_version}" | getclm 2)"
                    [[ "${debug}" = true ]] && echo -ne " ${_result[1]}\n"
                    msg_warn "The version of ${_pkg} installed in local does not match one of the latest.\nLocal: ${_local} Latest: ${_latest}"
                    ;;
                "3")
                    [[ "${debug}" = true ]] && echo
                    msg_error "${_pkg} is not installed." ; _check_failed=true
                    ;;
                "4")
                    [[ "${debug}" = true ]] && echo
                    msg_error "pyalpm is not installed." ; exit 1
                    ;;
            esac
            _result=0
        done
        if [[ "${_check_failed}" = true ]]; then exit 1; fi
    fi

    # Load loop kernel module
    if [[ "${noloopmod}" = false ]]; then
        if [[ ! -d "/usr/lib/modules/$(uname -r)" ]]; then
            msg_error "The currently running kernel module could not be found.\nProbably the system kernel has been updated.\nReboot your system to run the latest kernel." "1"
        fi
        if [[ -z "$(lsmod | getclm 1 | grep -x "loop")" ]]; then modprobe loop; fi
    fi

    # Create a working directory.
    [[ ! -d "${work_dir}" ]] && mkdir -p "${work_dir}"

    # Check work dir
    if [[ -n $(ls -a "${work_dir}" 2> /dev/null | grep -xv ".." | grep -xv ".") ]] && [[ "${normwork}" = false ]]; then
        umount_chroot_advance
        msg_info "Deleting the contents of ${work_dir}..."
        "${tools_dir}/clean.sh" -o -w $(realpath "${work_dir}") $([[ "${debug}" = true ]] && echo -n "-d")
    fi

    # 強制終了時に作業ディレクトリを削除する
    local _trap_remove_work
    _trap_remove_work() {
        local status=${?}
        if [[ "${normwork}" = false ]]; then
            echo
            "${tools_dir}/clean.sh" -o -w $(realpath "${work_dir}") $([[ "${debug}" = true ]] && echo -n "-d")
        fi
        exit ${status}
    }
    trap '_trap_remove_work' 1 2 3 15
}


# Show settings.
show_settings() {
    if [[ "${boot_splash}" = true ]]; then
        msg_info "Boot splash is enabled."
        msg_info "Theme is used ${theme_name}."
    fi
    msg_info "Language is ${locale_fullname}."
    msg_info "Use the ${kernel} kernel."
    msg_info "Live username is ${username}."
    msg_info "Live user password is ${password}."
    msg_info "The compression method of squashfs is ${sfs_comp}."
    if [[ $(echo "${channel_name}" | sed 's/^.*\.\([^\.]*\)$/\1/') = "add" ]]; then
        msg_info "Use the $(echo ${channel_name} | sed 's/\.[^\.]*$//') channel."
    else
        msg_info "Use the ${channel_name} channel."
    fi
    msg_info "Build with architecture ${arch}."
    if [[ ${noconfirm} = false ]]; then
        echo
        echo "Press Enter to continue or Ctrl + C to cancel."
        read
    fi
    trap 1 2 3 15
    trap 'umount_trap' 1 2 3 15
}


# Preparation for build
prepare_build() {
    # Show alteriso version
    if [[ -d "${script_path}/.git" ]]; then
        cd  "${script_path}"
        msg_debug "The version of alteriso is $(git describe --long --tags | sed 's/\([^-]*-g\)/r\1/;s/-/./g')."
        cd - > /dev/null 2>&1
    fi

    # Pacman configuration file used only when building
    # If there is pacman.conf for each channel, use that for building
    if [[ -f "${channel_dir}/pacman-${arch}.conf" ]]; then
        build_pacman_conf="${channel_dir}/pacman-${arch}.conf"
    else
        build_pacman_conf="${script_path}/system/pacman-${arch}.conf"
    fi

    # Set dirs
    airootfs_dir="${work_dir}/${arch}/airootfs"
    isofs_dir="${work_dir}/iso"

    # Create dir
    mkdir -p "${airootfs_dir}"

    # Load configs
    load_config "${channel_dir}/config.any" "${channel_dir}/config.${arch}"

    # Debug mode
    if [[ "${bash_debug}" = true ]]; then
        set -x -v
    fi

    # Legacy mode
    if [[ "$(bash "${tools_dir}/channel.sh" --version "${alteriso_version}" ver "${channel_name}")" = "3.0" ]]; then
        msg_warn "The module cannot be used because it works with Alter ISO3.0 compatibility."
        if [[ ! -z "${include_extra+SET}" ]]; then
            if [[ "${include_extra}" = true ]]; then
                modules=("share" "share-extra" "base" "zsh-powerline")
            else
                modules=("share" "base")
            fi
        fi
    fi

    local module_check
    module_check(){
        msg_debug "Checking ${1} module ..."
        if ! bash "${tools_dir}/module.sh" check "${1}"; then
            msg_error "Module ${1} is not available." "1";
        fi
    }
    for_module "module_check {}"
    modules=($(printf "%s\n" "${modules[@]}" | sort | uniq))
    for_module load_config "${module_dir}/{}/config.any" "${module_dir}/{}/config.${arch}"
    msg_debug "Loaded modules: ${modules[*]}"
    if ! printf "%s\n" "${modules[@]}" | grep -x "share" >/dev/null 2>&1; then
        msg_warn "The share module is not loaded."
    fi

    # Set kernel
    if [[ "${customized_kernel}" = false ]]; then
        kernel="${defaultkernel}"
    fi

    # Parse files
    eval $(bash "${tools_dir}/locale.sh" -s -a "${arch}" get "${locale_name}")
    eval $(bash "${tools_dir}/kernel.sh" -s -c "${channel_name}" -a "${arch}" get "${kernel}")

    # Set username
    if [[ "${customized_username}" = false ]]; then
        username="${defaultusername}"
    fi

    # Set password
    if [[ "${customized_password}" = false ]]; then
        password="${defaultpassword}"
    fi

    # gitversion
    if [[ "${gitversion}" = true ]]; then
        cd "${script_path}"
        iso_version=${iso_version}-$(git rev-parse --short HEAD)
        cd - > /dev/null 2>&1
    fi

    # Generate iso file name.
    local _channel_name="${channel_name%.add}-${locale_version}"
    if [[ "${nochname}" = true ]]; then
        iso_filename="${iso_name}-${iso_version}-${arch}.iso"
    else
        iso_filename="${iso_name}-${_channel_name}-${iso_version}-${arch}.iso"
    fi
    msg_debug "Iso filename is ${iso_filename}"

    # check bool
    check_bool boot_splash cleaning noconfirm nodepend customized_username customized_password noloopmod nochname tarball noiso noaur customized_syslinux norescue_entry debug bash_debug nocolor msgdebug noefi nosigcheck

    # Check architecture for each channel
    local _exit=0
    bash "${tools_dir}/channel.sh" --version "${alteriso_version}" -a ${arch} -n -b check "${channel_name}" || _exit="${?}"
    if (( "${_exit}" != 0 )) && (( "${_exit}" != 1 )); then
        msg_error "${channel_name} channel does not support current architecture (${arch})." "1"
    fi

    # Unmount
    umount_chroot
}


# Setup custom pacman.conf with current cache directories.
make_pacman_conf() {
    msg_debug "Use ${build_pacman_conf}"
    if [[ "${nosigcheck}" = true ]]; then
        sed -r "s|^#?\\s*SigLevel.+|SigLevel = Never|g" ${build_pacman_conf} > "${work_dir}/pacman-${arch}.conf"
    else
        cp "${build_pacman_conf}" "${work_dir}/pacman-${arch}.conf"
    fi
}

# Base installation (airootfs)
make_basefs() {
    msg_info "Creating ext4 image of 32GiB..."
    truncate -s 32G -- "${airootfs_dir}.img"
    mkfs.ext4 -O '^has_journal,^resize_inode' -E 'lazy_itable_init=0' -m 0 -F -- "${airootfs_dir}.img" 32G
    tune2fs -c "0" -i "0" "${airootfs_dir}.img"
    msg_info "Done!"

    msg_info "Mounting ${airootfs_dir}.img on ${airootfs_dir}"
    mount_airootfs
    msg_info "Done!"

    #_pacman "base" "syslinux"
}

# Additional packages (airootfs)
make_packages_repo() {
    local _pkg _pkglist_args="-a ${arch} -k ${kernel} -c ${channel_dir} -l ${locale_name}"

    # get pkglist
    if [[ "${boot_splash}"   = true ]]; then _pkglist_args+=" -b"; fi
    if [[ "${debug}"         = true ]]; then _pkglist_args+=" -d"; fi
    if [[ "${memtest86}"     = true ]]; then _pkglist_args+=" -m"; fi
    _pkglist_args+=" ${modules[*]}"

    local _pkglist=($("${tools_dir}/pkglist.sh" ${_pkglist_args}))

    # Create a list of packages to be finally installed as packages.list directly under the working directory.
    echo -e "# The list of packages that is installed in live cd.\n#\n\n" > "${work_dir}/packages.list"
    printf "%s\n" "${_pkglist[@]}" >> "${work_dir}/packages.list"

    # Install packages on airootfs
    _pacman "${_pkglist[@]}"
}

make_packages_aur() {
    local _pkg _pkglist_args="--aur -a ${arch} -k ${kernel} -c ${channel_dir} -l ${locale_name}"

    # get pkglist
    # get pkglist
    if [[ "${boot_splash}"   = true ]]; then _pkglist_args+=" -b"; fi
    if [[ "${debug}"         = true ]]; then _pkglist_args+=" -d"; fi
    if [[ "${memtest86}"     = true ]]; then _pkglist_args+=" -m"; fi
    _pkglist_args+=" ${modules[*]}"

    local _pkglist_aur=($("${tools_dir}/pkglist.sh" ${_pkglist_args}))

    # Create a list of packages to be finally installed as packages.list directly under the working directory.
    echo -e "\n\n# AUR packages.\n#\n\n" >> "${work_dir}/packages.list"
    #for _pkg in ${_pkglist_aur[@]}; do echo ${_pkg} >> "${work_dir}/packages.list"; done
    printf "%s\n" "${_pkglist_aur[@]}" >> "${work_dir}/packages.list"

    # prepare for yay
    cp -rf --preserve=mode "${script_path}/system/aur.sh" "${airootfs_dir}/root/aur.sh"
    cp -rf --preserve=mode "/usr/bin/yay" "${airootfs_dir}/usr/local/bin/yay"

    sed "s|https|http|g" "${work_dir}/pacman-${arch}.conf" > "${airootfs_dir}/etc/alteriso-pacman.conf"

    # Run aur script
    _chroot_run "bash $([[ "${bash_debug}" = true ]] && echo -n "-x") /root/aur.sh ${_pkglist_aur[*]}"

    # Remove script
    remove "${airootfs_dir}/root/aur.sh" "${airootfs_dir}/usr/local/bin/yay"
}

make_pkgbuild() {
    #-- PKGBUILDが入ってるディレクトリの一覧 --#
    local _pkgbuild_dirs=("${channel_dir}/pkgbuild.any" "${channel_dir}/pkgbuild.${arch}")
    for_module '_pkgbuild_dirs+=("${module_dir}/{}/pkgbuild.any" "${module_dir}/{}/pkgbuild.${arch}")'

    #-- PKGBUILDが入ったディレクトリを作業ディレクトリにコピー --#
    for _dir in $(find "${_pkgbuild_dirs}" -type f -name "PKGBUILD" 2>/dev/null | xargs -If realpath f | xargs -If dirname f); do
        mkdir -p "${airootfs_dir}/pkgbuilds/"
        cp -r "${_dir}" "${airootfs_dir}/pkgbuilds/"
    done
    
    #-- ビルドスクリプトの実行 --#
    # prepare for makepkg
    cp -rf --preserve=mode "${script_path}/system/pkgbuild.sh" "${airootfs_dir}/root/pkgbuild.sh"
    cp -rf --preserve=mode "/usr/bin/yay" "${airootfs_dir}/usr/local/bin/yay"
    sed "s|https|http|g" "${work_dir}/pacman-${arch}.conf" > "${airootfs_dir}/etc/alteriso-pacman.conf"

    # Run build script
    _chroot_run "bash $([[ "${bash_debug}" = true ]] && echo -n "-x") /root/pkgbuild.sh /pkgbuilds"

    # Remove script
    remove "${airootfs_dir}/root/pkgbuild.sh" "${airootfs_dir}/usr/local/bin/yay"
}

# Customize installation (airootfs)
make_customize_airootfs() {
    # Overwrite airootfs with customize_airootfs.
    local _airootfs _airootfs_script_options _script _script_list _airootfs_list _main_script

    _airootfs_list=("${channel_dir}/airootfs.${arch}" "${channel_dir}/airootfs.any")
    for_module '_airootfs_list+=("${module_dir}/{}/airootfs.${arch}" "${module_dir}/{}/airootfs.any")'

    for _airootfs in ${_airootfs_list[@]};do
        if [[ -d "${_airootfs}" ]]; then
            cp -af "${_airootfs}"/* "${airootfs_dir}"
        fi
    done

    # Replace /etc/mkinitcpio.conf if Plymouth is enabled.
    if [[ "${boot_splash}" = true ]]; then
        cp -f "${script_path}/mkinitcpio/mkinitcpio-plymouth.conf" "${airootfs_dir}/etc/mkinitcpio.conf"
    else
        cp -f "${script_path}/mkinitcpio/mkinitcpio.conf" "${airootfs_dir}/etc/mkinitcpio.conf"
    fi
    
    # customize_airootfs options
    # -b                        : Enable boot splash.
    # -d                        : Enable debug mode.
    # -g <locale_gen_name>      : Set locale-gen.
    # -i <inst_dir>             : Set install dir
    # -k <kernel config line>   : Set kernel name.
    # -o <os name>              : Set os name.
    # -p <password>             : Set password.
    # -s <shell>                : Set user shell.
    # -t                        : Set plymouth theme.
    # -u <username>             : Set live user name.
    # -x                        : Enable bash debug mode.
    # -z <locale_time>          : Set the time zone.
    # -l <locale_name>          : Set language.
    #
    # -j is obsolete in AlterISO3 and cannot be used.
    # -r is obsolete due to the removal of rebuild.
    # -k changed in AlterISO3 from passing kernel name to passing kernel configuration.


    # Generate options of customize_airootfs.sh.
    _airootfs_script_options="-p '${password}' -k '${kernel} ${kernel_filename} ${kernel_mkinitcpio_profile}' -u '${username}' -o '${os_name}' -i '${install_dir}' -s '${usershell}' -a '${arch}' -g '${locale_gen_name}' -l '${locale_name}' -z '${locale_time}' -t ${theme_name}"
    [[ "${boot_splash}" = true ]] && _airootfs_script_options="${_airootfs_script_options} -b"
    [[ "${debug}" = true       ]] && _airootfs_script_options="${_airootfs_script_options} -d"
    [[ "${bash_debug}" = true  ]] && _airootfs_script_options="${_airootfs_script_options} -x"

    
    _main_script="root/customize_airootfs.sh"

    _script_list=(
        "${airootfs_dir}/root/customize_airootfs_${channel_name}.sh"
        "${airootfs_dir}/root/customize_airootfs_${channel_name%.add}.sh"
    )

    for_module '_script_list+=("${airootfs_dir}/root/customize_airootfs_{}.sh")'

    # Create script
    for _script in ${_script_list[@]}; do
        if [[ -f "${_script}" ]]; then
            echo -e "\n" >> "${airootfs_dir}/${_main_script}"
            cat "${_script}" >> "${airootfs_dir}/${_main_script}"
            remove "${_script}"
        fi
    done

    chmod 755 "${airootfs_dir}/${_main_script}"
    cp "${airootfs_dir}/${_main_script}" "${work_dir}/$(basename ${_main_script})"
    _chroot_run "${_main_script} ${_airootfs_script_options}"
    remove "${airootfs_dir}/${_main_script}"

    # /root permission https://github.com/archlinux/archiso/commit/d39e2ba41bf556674501062742190c29ee11cd59
    chmod -f 750 "${airootfs_dir}/root"
}

# Copy mkinitcpio archiso hooks and build initramfs (airootfs)
make_setup_mkinitcpio() {
    local _hook
    mkdir -p "${airootfs_dir}/etc/initcpio/hooks"
    mkdir -p "${airootfs_dir}/etc/initcpio/install"
    for _hook in "archiso" "archiso_shutdown" "archiso_pxe_common" "archiso_pxe_nbd" "archiso_pxe_http" "archiso_pxe_nfs" "archiso_loop_mnt"; do
        cp "${script_path}/system/initcpio/hooks/${_hook}" "${airootfs_dir}/etc/initcpio/hooks"
        cp "${script_path}/system/initcpio/install/${_hook}" "${airootfs_dir}/etc/initcpio/install"
    done
    sed -i "s|/usr/lib/initcpio/|/etc/initcpio/|g" "${airootfs_dir}/etc/initcpio/install/archiso_shutdown"
    cp "${script_path}/system/initcpio/install/archiso_kms" "${airootfs_dir}/etc/initcpio/install"
    cp "${script_path}/system/initcpio/archiso_shutdown" "${airootfs_dir}/etc/initcpio"
    if [[ "${boot_splash}" = true ]]; then
        cp "${script_path}/mkinitcpio/mkinitcpio-archiso-plymouth.conf" "${airootfs_dir}/etc/mkinitcpio-archiso.conf"
    else
        cp "${script_path}/mkinitcpio/mkinitcpio-archiso.conf" "${airootfs_dir}/etc/mkinitcpio-archiso.conf"
    fi
    if [[ "${gpg_key}" ]]; then
      gpg --export "${gpg_key}" >"${work_dir}/gpgkey"
      exec 17<>"${work_dir}/gpgkey"
    fi

    _chroot_run "mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/${kernel_filename} -g /boot/archiso.img"

    if [[ "${gpg_key}" ]]; then
        exec 17<&-
    fi
}

# Prepare kernel/initramfs ${install_dir}/boot/
make_boot() {
    mkdir -p "${isofs_dir}/${install_dir}/boot/${arch}"
    cp "${airootfs_dir}/boot/archiso.img" "${isofs_dir}/${install_dir}/boot/${arch}/archiso.img"
    cp "${airootfs_dir}/boot/${kernel_filename}" "${isofs_dir}/${install_dir}/boot/${arch}/${kernel_filename}"
}

# Add other aditional/extra files to ${install_dir}/boot/
make_boot_extra() {
    if [[ -e "${airootfs_dir}/boot/memtest86+/memtest.bin" ]]; then
        cp "${airootfs_dir}/boot/memtest86+/memtest.bin" "${isofs_dir}/${install_dir}/boot/memtest"
        cp "${airootfs_dir}/usr/share/licenses/common/GPL2/license.txt" "${isofs_dir}/${install_dir}/boot/memtest.COPYING"
    fi

    local _ucode_image
    msg_info "Preparing microcode for the ISO 9660 file system..."

    for _ucode_image in {intel-uc.img,intel-ucode.img,amd-uc.img,amd-ucode.img,early_ucode.cpio,microcode.cpio}; do
        if [[ -e "${airootfs_dir}/boot/${_ucode_image}" ]]; then
            install -m 0644 -- "${airootfs_dir}/boot/${_ucode_image}" "${isofs_dir}/${install_dir}/boot/"
            if [[ -e "${airootfs_dir}/usr/share/licenses/${_ucode_image%.*}/" ]]; then
                install -d -m 0755 -- "${isofs_dir}/${install_dir}/boot/licenses/${_ucode_image%.*}/"
                install -m 0644 -- "${airootfs_dir}/usr/share/licenses/${_ucode_image%.*}/"* "${isofs_dir}/${install_dir}/boot/licenses/${_ucode_image%.*}/"
            fi
        fi
    done
    msg_info "Done!"
}

# Prepare /${install_dir}/boot/syslinux
make_syslinux() {
    _uname_r="$(file -b ${airootfs_dir}/boot/${kernel_filename} | awk 'f{print;f=0} /version/{f=1}' RS=' ')"
    mkdir -p "${isofs_dir}/${install_dir}/boot/syslinux"

    # 一時ディレクトリに設定ファイルをコピー
    mkdir -p "${work_dir}/${arch}/syslinux/"
    cp -a "${script_path}/syslinux/"* "${work_dir}/${arch}/syslinux/"
    if [[ -d "${channel_dir}/syslinux" ]] && [[ "${customized_syslinux}" = true ]]; then
        cp -af "${channel_dir}/syslinux"* "${work_dir}/${arch}/syslinux/"
    fi

    # copy all syslinux config to work dir
    for _cfg in ${work_dir}/${arch}/syslinux/*.cfg; do
        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%OS_NAME%|${os_name}|g;
             s|%KERNEL_FILENAME%|${kernel_filename}|g;
             s|%ARCH%|${arch}|g;
             s|%INSTALL_DIR%|${install_dir}|g" "${_cfg}" > "${isofs_dir}/${install_dir}/boot/syslinux/${_cfg##*/}"
    done

    # Replace the SYSLINUX configuration file with or without boot splash.
    local _use_config_name _no_use_config_name _pxe_or_sys
    if [[ "${boot_splash}" = true ]]; then
        _use_config_name=splash
        _no_use_config_name=nosplash
    else
        _use_config_name=nosplash
        _no_use_config_name=splash
    fi
    for _pxe_or_sys in "sys" "pxe"; do
        remove "${isofs_dir}/${install_dir}/boot/syslinux/archiso_${_pxe_or_sys}_${_no_use_config_name}.cfg"
        mv "${isofs_dir}/${install_dir}/boot/syslinux/archiso_${_pxe_or_sys}_${_use_config_name}.cfg" "${isofs_dir}/${install_dir}/boot/syslinux/archiso_${_pxe_or_sys}.cfg"
    done

    # Set syslinux wallpaper
    if [[ -f "${channel_dir}/splash.png" ]]; then
        cp "${channel_dir}/splash.png" "${isofs_dir}/${install_dir}/boot/syslinux"
    else
        cp "${script_path}/syslinux/splash.png" "${isofs_dir}/${install_dir}/boot/syslinux"
    fi

    # remove config
    local _remove_config
    function _remove_config() {
        remove "${isofs_dir}/${install_dir}/boot/syslinux/${1}"
        sed -i "s|$(cat "${isofs_dir}/${install_dir}/boot/syslinux/archiso_sys_load.cfg" | grep "${1}")||g" "${isofs_dir}/${install_dir}/boot/syslinux/archiso_sys_load.cfg" 
    }

    if [[ "${norescue_entry}" = true ]]; then
        _remove_config archiso_sys_rescue.cfg
    fi

    if [[ "${memtest86}" = false ]]; then
        _remove_config memtest86.cfg
    fi

    # copy files
    cp "${work_dir}"/${arch}/airootfs/usr/lib/syslinux/bios/*.c32 "${isofs_dir}/${install_dir}/boot/syslinux"
    cp "${airootfs_dir}/usr/lib/syslinux/bios/lpxelinux.0" "${isofs_dir}/${install_dir}/boot/syslinux"
    cp "${airootfs_dir}/usr/lib/syslinux/bios/memdisk" "${isofs_dir}/${install_dir}/boot/syslinux"
    mkdir -p "${isofs_dir}/${install_dir}/boot/syslinux/hdt"
    gzip -c -9 "${airootfs_dir}/usr/share/hwdata/pci.ids" > "${isofs_dir}/${install_dir}/boot/syslinux/hdt/pciids.gz"
    gzip -c -9 "${airootfs_dir}/usr/lib/modules/${_uname_r}/modules.alias" > "${isofs_dir}/${install_dir}/boot/syslinux/hdt/modalias.gz"
}

# Prepare /isolinux
make_isolinux() {
    mkdir -p "${isofs_dir}/isolinux"

    sed "s|%INSTALL_DIR%|${install_dir}|g" \
    "${script_path}/system/isolinux.cfg" > "${isofs_dir}/isolinux/isolinux.cfg"
    cp "${airootfs_dir}/usr/lib/syslinux/bios/isolinux.bin" "${isofs_dir}/isolinux/"
    cp "${airootfs_dir}/usr/lib/syslinux/bios/isohdpfx.bin" "${isofs_dir}/isolinux/"
    cp "${airootfs_dir}/usr/lib/syslinux/bios/ldlinux.c32" "${isofs_dir}/isolinux/"
}

# Prepare /EFI
make_efi() {
    install -d -m 0755 -- "${isofs_dir}/EFI/boot"

    local _bootfile="$(basename "$(ls "${airootfs_dir}/usr/lib/systemd/boot/efi/systemd-boot"*".efi" )")"
    #cp "${airootfs_dir}/usr/lib/systemd/boot/efi/${_bootfile}" "${isofs_dir}/EFI/boot/${_bootfile#systemd-}"
    install -m 0644 -- "${airootfs_dir}/usr/lib/systemd/boot/efi/${_bootfile}" "${isofs_dir}/EFI/boot/${_bootfile#systemd-}"

    local _use_config_name="nosplash"
    if [[ "${boot_splash}" = true ]]; then
        _use_config_name="splash"
    fi

    install -d -m 0755 -- "${isofs_dir}/loader/entries"
    sed "s|%ARCH%|${arch}|g;" "${script_path}/efiboot/${_use_config_name}/loader.conf" > "${isofs_dir}/loader/loader.conf"

    local _efi_config_list=() _efi_config
    _efi_config_list+=($(ls "${script_path}/efiboot/${_use_config_name}/archiso-usb"*".conf" | grep -v "rescue"))

    if [[ "${norescue_entry}" = false ]]; then
        _efi_config_list+=($(ls "${script_path}/efiboot/${_use_config_name}/archiso-usb"*".conf" | grep -v "rescue"))
    fi

    for _efi_config in ${_efi_config_list[@]}; do
        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
            s|%OS_NAME%|${os_name}|g;
            s|%KERNEL_FILENAME%|${kernel_filename}|g;
            s|%ARCH%|${arch}|g;
            s|%INSTALL_DIR%|${install_dir}|g" \
        "${_efi_config}" > "${isofs_dir}/loader/entries/$(basename "${_efi_config}" | sed "s|usb|${arch}|g")"
    done

    # edk2-shell based UEFI shell
    local _efi_shell _efi_shell_arch
    for _efi_shell in "${work_dir}"/${arch}/airootfs/usr/share/edk2-shell/*; do
        _efi_shell_arch="$(basename ${_efi_shell})"
        if [[ "${_efi_shell_arch}" == 'aarch64' ]]; then
            cp "${_efi_shell}/Shell.efi" "${isofs_dir}/EFI/shell_${_efi_shell_arch}.efi"
        else
            cp "${_efi_shell}/Shell_Full.efi" "${isofs_dir}/EFI/shell_${_efi_shell_arch}.efi"
        fi
        cat - > "${isofs_dir}/loader/entries/uefi-shell-${_efi_shell_arch}.conf" << EOF
title  UEFI Shell ${_efi_shell_arch}
efi    /EFI/shell_${_efi_shell_arch}.efi

EOF
    done
}

# Prepare efiboot.img::/EFI for "El Torito" EFI boot mode
make_efiboot() {
    mkdir -p "${isofs_dir}/EFI/alteriso"
    truncate -s 128M "${isofs_dir}/EFI/alteriso/efiboot.img"
    mkfs.fat -n ARCHISO_EFI "${isofs_dir}/EFI/alteriso/efiboot.img"

    mkdir -p "${work_dir}/efiboot"
    mount "${isofs_dir}/EFI/alteriso/efiboot.img" "${work_dir}/efiboot"

    mkdir -p "${work_dir}/efiboot/EFI/alteriso/${arch}"
    cp "${isofs_dir}/${install_dir}/boot/${arch}/${kernel_filename}" "${work_dir}/efiboot/EFI/alteriso/${arch}/${kernel_filename}.efi"
    cp "${isofs_dir}/${install_dir}/boot/${arch}/archiso.img" "${work_dir}/efiboot/EFI/alteriso/${arch}/archiso.img"

    local _ucode_image
    for _ucode_image in "${airootfs_dir}/boot/"{intel-uc.img,intel-ucode.img,amd-uc.img,amd-ucode.img,early_ucode.cpio,microcode.cpio}; do
        [[ -e "${_ucode_image}" ]] && cp "${_ucode_image}" "${work_dir}/efiboot/EFI/alteriso/"
    done

    mkdir -p "${work_dir}/efiboot/EFI/boot"

    # PreLoader.efiがefitoolsのi686版に存在しません。この行を有効化するとi686ビルドに失敗します
    # PreLoader.efiの役割がわかりません誰かたすけてください（archiso v43で使用されていた）
    #cp "${airootfs_dir}/usr/share/efitools/efi/PreLoader.efi" "${work_dir}/efiboot/EFI/boot/bootx64.efi"

    cp "${airootfs_dir}/usr/share/efitools/efi/HashTool.efi" "${work_dir}/efiboot/EFI/boot/"

    local _bootfile="$(basename "$(ls "${airootfs_dir}/usr/lib/systemd/boot/efi/systemd-boot"*".efi" )")"
    cp "${airootfs_dir}/usr/lib/systemd/boot/efi/${_bootfile}" "${work_dir}/efiboot/EFI/boot/${_bootfile#systemd-}"

    local _use_config_name
    if [[ "${boot_splash}" = true ]]; then
        _use_config_name="splash"
    else
        _use_config_name="nosplash"
    fi

    mkdir -p "${work_dir}/efiboot/loader/entries"
    sed "s|%ARCH%|${arch}|g;" "${script_path}/efiboot/${_use_config_name}/loader.conf" > "${work_dir}/efiboot/loader/loader.conf"
    cp "${isofs_dir}/loader/entries/uefi-shell"* "${work_dir}/efiboot/loader/entries/"

    local _efi_config_list=() _efi_config
    _efi_config_list+=($(ls "${script_path}/efiboot/${_use_config_name}/archiso-cd"*".conf" | grep -v "rescue"))

    if [[ "${norescue_entry}" = false ]]; then
        _efi_config_list+=($(ls "${script_path}/efiboot/${_use_config_name}/archiso-cd"*".conf" | grep -v "rescue"))
    fi

    for _efi_config in ${_efi_config_list[@]}; do
        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
            s|%OS_NAME%|${os_name}|g;
            s|%KERNEL_FILENAME%|${kernel_filename}|g;
            s|%ARCH%|${arch}|g;
            s|%INSTALL_DIR%|${install_dir}|g" \
        "${_efi_config}" > "${work_dir}/efiboot/loader/entries/$(basename "${_efi_config}" | sed "s|cd|${arch}|g")"
    done

    cp "${isofs_dir}/EFI/shell"*".efi" "${work_dir}/efiboot/EFI/"
    umount -d "${work_dir}/efiboot"
}

# Compress tarball
make_tarball() {
    # backup airootfs.img for tarball
    msg_info "Copying airootfs.img ..."
    cp "${airootfs_dir}.img" "${airootfs_dir}.img.org"

    # Run script
    mount_airootfs
    if [[ -f "${airootfs_dir}/root/optimize_for_tarball.sh" ]]; then
        chmod 755 "${airootfs_dir}/root/optimize_for_tarball.sh"
        # Execute optimize_for_tarball.sh.
        _chroot_run "/root/optimize_for_tarball.sh -u ${username}"
    fi

    _cleanup_common
    _chroot_run "mkinitcpio -P"

    remove "${airootfs_dir}/root/optimize_for_tarball.sh"

    mkdir -p "${out_dir}"
    msg_info "Creating tarball..."
    local tar_path="$(realpath ${out_dir})/${iso_filename%.iso}.tar.xz"
    cd -- "${airootfs_dir}"
    tar -v -J -p -c -f "${tar_path}" ./*
    cd -- "${OLDPWD}"

    _mkchecksum "${tar_path}"
    msg_info "Done! | $(ls -sh ${tar_path})"

    remove "${airootfs_dir}.img"
    mv "${airootfs_dir}.img.org" "${airootfs_dir}.img"

    if [[ "${noiso}" = true ]]; then
        msg_info "The password for the live user and root is ${password}."
    fi
}


# Build airootfs filesystem image
make_prepare() {
    mount_airootfs

    # Create packages list
    msg_info "Creating a list of installed packages on live-enviroment..."
    pacman-key --init
    pacman -Q --sysroot "${airootfs_dir}" | tee "${isofs_dir}/${install_dir}/pkglist.${arch}.txt" "${work_dir}/packages-full.list" > /dev/null

    # Cleanup
    remove "${airootfs_dir}/root/optimize_for_tarball.sh"
    _cleanup_airootfs

    # Create squashfs
    mkdir -p -- "${isofs_dir}/${install_dir}/${arch}"
    msg_info "Creating SquashFS image, this may take some time..."
    mksquashfs "${airootfs_dir}" "${work_dir}/iso/${install_dir}/${arch}/airootfs.sfs" -noappend -comp "${sfs_comp}" ${sfs_comp_opt}

    # Create checksum
    msg_info "Creating checksum file for self-test..."
    cd -- "${isofs_dir}/${install_dir}/${arch}"
    sha512sum airootfs.sfs > airootfs.sha512
    cd -- "${OLDPWD}"
    msg_info "Done!"

    # Sign with gpg
    if [[ -v gpg_key ]] && (( "${#gpg_key}" != 0 )); then
        msg_info "Creating signature file ($gpg_key) ..."
        cd -- "${isofs_dir}/${install_dir}/${arch}"
        gpg --detach-sign --default-key "${gpg_key}" "airootfs.sfs"
        cd -- "${OLDPWD}"
        msg_info "Done!"
    fi

    umount_chroot_advance

    if [[ "${cleaning}" = true ]]; then
        remove "${airootfs_dir}" "${airootfs_dir}.img"
    fi
}

make_alteriso_info(){
    # iso version info
    if [[ "${include_info}" = true ]]; then
        local _info_file="${isofs_dir}/alteriso-info" _version="${iso_version}"
        remove "${_info_file}"; touch "${_info_file}"
        if [[ -d "${script_path}/.git" ]] && [[ "${gitversion}" = false ]]; then
            _version="${iso_version}-$(git rev-parse --short HEAD)"
        fi
        "${tools_dir}/alteriso-info.sh" -a "${arch}" -b "${boot_splash}" -c "${channel_name%.add}" -d "${iso_publisher}" -k "${kernel}" -o "${os_name}" -p "${password}" -u "${username}" -v "${_version}" > "${_info_file}"
    fi
}

# Add files to the root of isofs
make_overisofs() {
    local _over_isofs_list _isofs
    _over_isofs_list=("${channel_dir}/over_isofs.any""${channel_dir}/over_isofs.${arch}")
    for_module '_over_isofs_list+=("${module_dir}/{}/over_isofs.any""${module_dir}/{}/over_isofs.${arch}")'
    for _isofs in ${_over_isofs_list[@]}; do
        if [[ -d "${_isofs}" ]]; then cp -af "${_isofs}"/* "${isofs_dir}"; fi
    done
}

# Build ISO
make_iso() {
    local _iso_efi_boot_args=""
    if [[ ! -f "${work_dir}/iso/isolinux/isolinux.bin" ]]; then
         _msg_error "The file '${work_dir}/iso/isolinux/isolinux.bin' does not exist." 1
    fi
    if [[ ! -f "${work_dir}/iso/isolinux/isohdpfx.bin" ]]; then
         _msg_error "The file '${work_dir}/iso/isolinux/isohdpfx.bin' does not exist." 1
    fi

    # If exists, add an EFI "El Torito" boot image (FAT filesystem) to ISO-9660 image.
    if [[ -f "${work_dir}/iso/EFI/alteriso/efiboot.img" ]]; then
        _iso_efi_boot_args="-eltorito-alt-boot
                            -e EFI/alteriso/efiboot.img
                            -no-emul-boot
                            -isohybrid-gpt-basdat"
    fi

    mkdir -p -- "${out_dir}"
    msg_info "Creating ISO image..."
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -joliet \
        -joliet-long \
        -rational-rock \
        -volid "${iso_label}" \
        -appid "${iso_application}" \
        -publisher "${iso_publisher}" \
        -preparer "prepared by AlterISO" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -isohybrid-mbr ${work_dir}/iso/isolinux/isohdpfx.bin \
        ${_iso_efi_boot_args} \
        -output "${out_dir}/${iso_filename}" \
        "${work_dir}/iso/"
    _mkchecksum "${iso_filename}"
    msg_info "Done! | $(ls -sh -- "${out_dir}/${iso_filename}")"

    msg_info "The password for the live user and root is ${password}."
}


# Parse options
ARGUMENT="${@}"
OPTS="a:bc:deg:hjk:l:o:p:rt:u:w:x"
OPTL="arch:,boot-splash,comp-type:,debug,cleaning,cleanup,gpgkey:,help,lang:,japanese,kernel:,out:,password:,comp-opts:,user:,work:,bash-debug,nocolor,noconfirm,nodepend,gitversion,msgdebug,noloopmod,tarball,noiso,noaur,nochkver,channellist,config:,noefi,nodebug,nosigcheck,normwork"
if ! OPT=$(getopt -o ${OPTS} -l ${OPTL} -- ${DEFAULT_ARGUMENT} ${ARGUMENT}); then
    exit 1
fi

eval set -- "${OPT}"
msg_debug "Argument: ${OPT}"
unset OPT OPTS OPTL

while :; do
    case "${1}" in
        -a | --arch)
            arch="${2}"
            shift 2
            ;;
        -b | --boot-splash)
            boot_splash=true
            shift 1
            ;;
        -c | --comp-type)
            case "${2}" in
                "gzip" | "lzma" | "lzo" | "lz4" | "xz" | "zstd") sfs_comp="${2}" ;;
                *) msg_error "Invaild compressors '${2}'" '1' ;;
            esac
            shift 2
            ;;
        -d | --debug)
            debug=true
            shift 1
            ;;
        -e | --cleaning | --cleanup)
            cleaning=true
            shift 1
            ;;
        -g | --gpgkey)
            gpg_key="${2}"
            shift 2
            ;;
        -h | --help)
            _usage
            exit 0
            ;;
        -j | --japanese)
            msg_error "This option is obsolete in AlterISO 3. To use Japanese, use \"-l ja\"." "1"
            ;;
        -k | --kernel)
            customized_kernel=true
            kernel="${2}"
            shift 2
            ;;
        -l | --lang)
            locale_name="${2}"
            shift 2
            ;;
        -o | --out)
            out_dir="${2}"
            shift 2
            ;;
        -p | --password)
            customized_password=true
            password="${2}"
            shift 2
            ;;
        -r | --tarball)
            tarball=true
            shift 1
            ;;
        -t | --comp-opts)
            if [[ "${2}" = "reset" ]]; then
                sfs_comp_opt=""
            else
                sfs_comp_opt="${2}"
            fi
            shift 2
            ;;
        -u | --user)
            customized_username=true
            username="$(echo -n "${2}" | sed 's/ //g' |tr '[A-Z]' '[a-z]')"
            shift 2
            ;;
        -w | --work)
            work_dir="${2}"
            shift 2
            ;;
        -x | --bash-debug)
            debug=true
            bash_debug=true
            shift 1
            ;;
        --noconfirm)
            noconfirm=true
            shift 1
            ;;
        --nodepend)
            nodepend=true
            shift 1
            ;;
        --nocolor)
            nocolor=true
            shift 1
            ;;
        --gitversion)
            if [[ -d "${script_path}/.git" ]]; then
                gitversion=true
            else
                msg_error "There is no git directory. You need to use git clone to use this feature." "1"
            fi
            shift 1
            ;;
        --msgdebug)
            msgdebug=true;
            shift 1
            ;;
        --noloopmod)
            noloopmod=true
            shift 1
            ;;
        --noiso)
            noiso=true
            shift 1
            ;;
        --noaur)
            noaur=true
            shift 1
            ;;
        --nochkver)
            nochkver=true
            shift 1
            ;;
        --nodebug)
            debug=false
            msgdebug=false
            bash_debug=false
            shift 1
            ;;
        --noefi)
            noefi=true
            shift 1
            ;;
        --channellist)
            show_channel_list
            exit 0
            ;;
        --config)
            source "${2}"
            shift 2
            ;;
        --nosigcheck)
            nosigcheck=true
            shift 1
            ;;
        --normwork)
            normwork=true
            shift 1
            ;;
        --)
            shift
            break
            ;;
        *)
            msg_error "Invalid argument '${1}'"
            _usage 1
            ;;
    esac
done


# Check root.
if (( ! "${EUID}" == 0 )); then
    msg_warn "This script must be run as root." >&2
    msg_warn "Re-run 'sudo ${0} ${DEFAULT_ARGUMENT} ${ARGUMENT}'"
    sudo ${0} ${DEFAULT_ARGUMENT} ${ARGUMENT}
    exit "${?}"
fi

unset DEFAULT_ARGUMENT ARGUMENT

# Show config message
msg_debug "Use the default configuration file (${defaultconfig})."
[[ -f "${script_path}/custom.conf" ]] && msg_debug "The default settings have been overridden by custom.conf"

# Debug mode
if [[ "${bash_debug}" = true ]]; then set -x -v; fi

# Check for a valid channel name
if [[ -n "${1+SET}" ]]; then
    case "$(bash "${tools_dir}/channel.sh" --version "${alteriso_version}" -n check "${1}"; printf "${?}")" in
        "2")
            msg_error "Invalid channel ${1}" "1"
            ;;
        "1")
            channel_dir="${1}"
            channel_name="$(basename "${1%/}")"
            ;;
        "0")
            channel_dir="${script_path}/channels/${1}"
            channel_name="${1}"
            ;;
    esac
else
    channel_dir="${script_path}/channels/${channel_name}"
fi

# Set for special channels
if [[ -d "${channel_dir}.add" ]]; then
    channel_name="${1}"
    channel_dir="${channel_dir}.add"
elif [[ "${channel_name}" = "clean" ]]; then
   "${tools_dir}/clean.sh" -w "$(realpath "${work_dir}")" $([[ "${debug}" = true ]] && echo -n "-d")
    exit 0
fi

# Check channel version
msg_debug "channel path is ${channel_dir}"
if [[ ! "$(bash "${tools_dir}/channel.sh" --version "${alteriso_version}" ver "${channel_name}" | cut -d "." -f 1)" = "$(echo "${alteriso_version}" | cut -d "." -f 1)" ]] && [[ "${nochkver}" = false ]]; then
    msg_error "This channel does not support Alter ISO 3."
    if [[ -d "${script_path}/.git" ]]; then
        msg_error "Please run \"git checkout alteriso-2\"" "1"
    else
        msg_error "Please download old version here.\nhttps://github.com/FascodeNet/alterlinux/releases" "1"
    fi
fi

set -eu

prepare_env
prepare_build
show_settings
run_once make_pacman_conf
run_once make_basefs # Mount airootfs
run_once make_packages_repo
[[ "${noaur}" = false ]] && run_once make_packages_aur
run_once make_pkgbuild
run_once make_customize_airootfs
run_once make_setup_mkinitcpio
[[ "${tarball}" = true ]] && run_once make_tarball
if [[ "${noiso}" = false ]]; then
    run_once make_syslinux
    run_once make_isolinux
    run_once make_boot
    run_once make_boot_extra
    if [[ "${noefi}" = false ]]; then
        run_once make_efi
        run_once make_efiboot
    fi
    run_once make_alteriso_info
    run_once make_prepare
    run_once make_overisofs
    run_once make_iso
fi

[[ "${cleaning}" = true ]] && "${tools_dir}/clean.sh" -o -w "$(realpath "${work_dir}")" $([[ "${debug}" = true ]] && echo -n "-d")

exit 0
