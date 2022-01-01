#!/bin/bash

# Prerequisites for MacOS
# brew install socat
# brew install coreutils

function usage() {
    echo """
$(basename $0) [-h] [-b <pyhton version>] [-r <pyhton version>] [-p <target port>]
Build/run docker:
    -h  help
    -b  build image using the specified Python version (3.7-3.11), e.g. '-b 3.9' for Python 3.9
    -r  run container
    -p  target port (default 8888)
"""
}

function exit_abnormal(){
    usage
    exit 1
}

function set_target_port(){
    target_port_arg=$1
    echo "target port arg: '${target_port}'"

    tmp_pat="([0-9]{4})"
    pat='^('$tmp_pat')$'

    [[ "${target_port_arg}" =~ ${pat} ]]
    echo "Full match: '${BASH_REMATCH[0]}'"
    echo "Match group 1: '${BASH_REMATCH[1]}'"
    target_port=${BASH_REMATCH[1]}
    echo "Target port: '${target_port}'"

    if [ -z ${target_port} ]; then
        echo "Invalid target port passed, no match found: '${target_port}'"
        exit_abnormal
    fi    

}

function set_python_version_and_tag(){
    python_version_arg=$1
    echo "python arg: '${python_arg}'"

    # allow python versions 3.7-3.11
    tmp_pat="(3.([7-9]|[1][0-1]))"
    pat='^('$tmp_pat')$'

    [[ "${python_version_arg}" =~ ${pat} ]]
    echo "Full match: '${BASH_REMATCH[0]}'"
    echo "Match group 1: '${BASH_REMATCH[1]}'"
    python_version=${BASH_REMATCH[1]}
    echo "Python version: '${python_version}'"
    if [ -z ${python_version} ]; then
        echo "Invalid Python version passed, no match found: '${python_version}'"
        exit_abnormal
    fi

    python_dist="buster"
    python_tag="${python_version}-${python_dist}"
    tag="${tag_prefix}:${python_tag}"
    imagename="${tag}"
}

function docker_build()
{
    set -x
    # base image
    docker build \
        --build-arg PYTHON_TAG=${python_tag} \
        --file ${dockerfile} \
        --tag $tag \
        .

    # check if succeeded
    exit_status=$?
    if [ $exit_status != 0 ]; then
        echo "Building base image failed!"
        exit 1
    fi

    if [ "$(uname -s)" == "Darvin" ]; then
        echo "OS detected: MacOS"
        echo "Not building non-root-user image"
    elif [ "$(uname -s)" == "Linux" ]; then
        # linux and wsl
        docker build \
            --build-arg BASE_IMAGE=${tag} \
            --build-arg USER_NAME=$USER \
            --build-arg USER_UID=$(id -u $USER) \
            --build-arg USER_GID=$(id -g $USER) \
            --file ${non_root_user}.${dockerfile} \
            --tag ${tag}-${non_root_user} \
            .
    else
        echo "OS not supported: '$(uname -s)'"
        echo "Not building non-root-user image"
        exit 1
    fi
    set +x
}

function docker_run(){
    # check if local workspace directory to be mounted is valid
    if [ ! -d "${dir_local_workspace}" ]; then
        echo "local workspace directory is not valid: '${dir_local_workspace}'"
        exit_abnormal
    fi

    workdir="/workspace"
    docker_params="""
        --rm
        --interactive
        --tty
        --workdir=${workdir}
        --volume $(realpath ${dir_local_workspace}/):${workdir}/
        --publish=${target_port}:8888
        """
    
    docker_command=""
    #"bash"

    os_detected="$(uname -s)"
    set -x
    if [ "${os_detected}" == "Darvin" ]; then
        docker run \
            ${docker_params} \
            --name ${containername} \
            ${imagename} 
            #"${docker_command}"
    elif [ "${os_detected}" == "Linux" ]; then
        docker run \
            ${docker_params} \
            --name ${containername}-${non_root_user} \
            --user $(id -u $user):$(id -g $user) \
            --env USER=${USER} \
            ${imagename}-${non_root_user} 
            #"${docker_command}"
    else
        echo "Not supported OS"
        exit 1
    fi
    set +x
}

#no_args=true
arg_build=false
arg_run=false
arg_target_port="8888"

while getopts "hb:r:p:" option; do
    case "${option}" in
        h) exit_abnormal;;
        b) arg_build=true; arg_python_version_build=${OPTARG};;
        r) arg_run=true; arg_python_version_run=${OPTARG};;
        p) arg_target_port=${OPTARG};;
        ?) echo "Unknown option: -$OPTARG" >&2; exit_abnormal;;
        *) echo "Unimplemented option: -$OPTARG" >&2; exit_abnormal;;
        #:) echo "Option -${OPTARG} requires argument" >&2; exit_abnormal;;
    esac
    #no_args=false
done

script_dir=$(dirname $0)
pushd ${script_dir}

dir_local_workspace="../"

containername="ft_lab_radon_eye"
tag_prefix="ai2ys/ft_lab_radon_eye/python"
dockerfile="dockerfile"
non_root_user="non-root-user"

# show usage in case neither build nor run is selected
if [ "${arg_build}" == false ] && [ "${arg_run}" == false ]; then { exit_abnormal; }; fi

# build docker image
if [ "${arg_build}" == true ]; then 
    set_python_version_and_tag ${arg_python_version_build}
    docker_build
fi

# run docker container
if [ "${arg_run}" == true ]; then 
    set_python_version_and_tag ${arg_python_version_run}
    set_target_port ${arg_target_port}
    docker_run
fi

popd