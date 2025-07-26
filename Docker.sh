#!/bin/bash

# Exit on error
set -e

# Change to the directory of the script
cd "$(dirname "$0")"

usage_message() {
cat << EOF
    Usage: $0 {run|stop|build|rebuild|clean_container|clean_image} [options]
        run             - Run the Docker container
        stop            - Stop the Docker container if running
        build           - Build the Docker image
        rebuild         - Rebuild the Docker image without cache
        clean_container - Stop and remove the Docker container
        clean_image     - Remove the Docker image

    Options:
        --username | -u    USERNAME                  Set the username for the container (default: current user)
        --image-name | -i  IMAGE_NAME                Set the name of the Docker image (required for run/build)
        --cont-name | -c   CONTAINER_NAME            Set the name of the Docker container (required for run)
        --mount | -m       HOST_PATH:CONTAINER_PATH  Mount a host directory into the container (can be used multiple times)
EOF
}

# Set default values for variables
ACTION="$1"; shift || { echo "Need to specify the action:"; usage_message; exit 1; }
USERNAME_DEFAULT="$(id -un)"
USERNAME=""
IMAGE_NAME="base"
CONTAINER_NAME="base_container"
MOUNTS=()

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -u|--username)
      [[ -z $2 || $2 == --* ]] && { echo "--username requires value"; exit 1; }
      USERNAME=$2; shift 2 ;;
    -i|--image-name)
      [[ -z $2 || $2 == --* ]] && { echo "--image-name requires value"; exit 1; }
      IMAGE_NAME=$2; shift 2 ;;
    -c|--cont-name)
      [[ -z $2 || $2 == --* ]] && { echo "--cont-name requires value"; exit 1; }
      CONTAINER_NAME=$2; shift 2 ;;
    -m|--mount)
      [[ -z $2 || $2 == --* ]] && { echo "--mount requires value"; exit 1; }
      MOUNTS+=("$2"); shift 2 ;;
    *)
    echo "Unknown flag: $1" && usage_message && exit 1 ;;
  esac
done
USERNAME="${USERNAME:-$USERNAME_DEFAULT}"

###############################################################################
# Utility:
# build Docker image if absent
# -----------------------------------------------------------------------------
# * Uses --build-arg to align UID/GID inside the image         (best-practice)
# * When called with "nocache", add --no-cache to docker build
###############################################################################
build_image() {
    local nocache="$1"
    [[ -z ${IMAGE_NAME} ]] && { echo "IMAGE_NAME is not set"; exit 1; }

    # Use inspect instead of grep to avoid partial matches
    if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
        docker build \
        ${nocache:+--no-cache} \
        --build-arg USERNAME="${USERNAME}" \
        --build-arg UID="$(id -u)" \
        --build-arg GID="$(id -g)" \
        -t "${IMAGE_NAME}" .
        echo "Image ${IMAGE_NAME} built."
    else
        echo "Image ${IMAGE_NAME} already exists."
    fi
}

###########################################################################
# Utility:
# Launch detached container and attach an interactive bash if not present
# -------------------------------------------------------------------------
#   * Builds -v flags from $MOUNTS array, preserving spaces in host paths.
#   * Exports USERID/GROUPID env vars so entrypoint can fix permissions.
###########################################################################
run_container() {
    [[ -z ${CONTAINER_NAME} ]] && { echo "CONTAINER_NAME is not set"; exit 1; }

    # Default mount if none is specified
    if [[ ${#MOUNTS[@]} -eq 0 ]]; then
        HOST_DEFAULT="./projects"
        CTR_DEFAULT="/home/${USERNAME}/projects"
        mkdir -p "$HOST_DEFAULT"
        MOUNTS+=("${HOST_DEFAULT}:${CTR_DEFAULT}")
    fi

    # Assemble -v flags
    local vols=()
    for m in "${MOUNTS[@]}"; do
        IFS=':' read -r host ctr <<<"$m"
        ctr=${ctr:-"/home/${USERNAME}/projects"}
        mkdir -p "$host"
        vols+=(-v "$host":"$ctr")
    done

    # Start only if container name not exists
    if ! docker ps -aq --filter name=^/${CONTAINER_NAME}$ | grep -q .; then
        docker run -it -d \
            -e USERID="$(id -u)" \
            -e GROUPID="$(id -g)" \
            -p 8888:8888 \
            "${vols[@]}" \
            --hostname "$(echo "$CONTAINER_NAME" | tr '[:lower:]' '[:upper:]')" \
            --name "${CONTAINER_NAME}" \
            "${IMAGE_NAME}"
    else
        echo "Container ${CONTAINER_NAME} already exists. Attaching..."
        docker start -ai "${CONTAINER_NAME}"
    fi

    # Interactive shell attach
    docker exec -it "${CONTAINER_NAME}" /bin/bash
}

##########################################################
# Utility:
# Stop currently running container named CONTAINER_NAME
##########################################################
stop_container() {
    docker stop  "${CONTAINER_NAME}" 2>/dev/null || true;
}

##########################################################
# Utility:
# Delete container named CONTAINER_NAME if exists
##########################################################
remove_container() {
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true;
}

##########################################################
# Utility:
# Delete local image named IMAGE_NAME if exists
##########################################################
remove_image() {
    docker rmi "${IMAGE_NAME}" 2>/dev/null || true;
}

# Options for the script based on the action
case $ACTION in
    run)
        # Run the Docker container
        run_container;
        exit 0
        ;;
    stop)
        # Stop the Docker container
        stop_container;
        exit 0
        ;;
    build)
        # Build the Docker image
        build_image;
        exit 0
        ;;
    rebuild)
        # Rebuild the Docker image
        stop_container;
        remove_container;
        remove_image;
        build_image nocache;
        exit 0
        ;;
    clean_container)
        # Clean up Docker container
        stop_container;      
        remove_container;
        exit 0
        ;;
    clean_image)
        # Clean up Docker image
        remove_image;
        exit 0
        ;;
    *)
        usage_message;
        ;;
esac