#!/bin/bash

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Update repo from git
if [ "${GIT_ENABLED}" == "false" ] || [ "${GIT_ENABLED}" == "0" ]; then
    echo -e "Using Git for version control."

    # Add git ending if it's not on the address
    if [[ ${GIT_ADDRESS} != *.git ]]; then
        GIT_ADDRESS=${GIT_ADDRESS}.git
    fi

    if [ -z "${GIT_USERNAME}" ] && [ -z "${GIT_ACCESS_TOKEN}" ]; then
        echo -e "Git Username or Git Token was not specified. Proceeding anonymously."
    else
        GIT_ADDRESS="https://${GIT_USERNAME}:${GIT_ACCESS_TOKEN}@$(echo -e ${GIT_ADDRESS} | cut -d/ -f3-)"
    fi

    # Update
    if [ "$(ls -A /home/container)" ]; then
        echo -e "/home/container directory is not empty."

        # Get git origin from /home/container/.git/config
        if [ -d .git ]; then
            echo -e ".git directory exists"
            if [ -f .git/config ]; then
                echo -e "loading info from git config"
                ORIGIN=$(git config --get remote.origin.url)
            else
                echo -e "files found with no git config"
                echo -e "closing out without touching things to not break anything"
                exit 10
            fi
        fi

        # If git origin matches the repo specified by user then pull
        if [ "${ORIGIN}" == "${GIT_ADDRESS}" ]; then
            echo "Pulling changes from Git."
            git pull && echo "Finished pulling /home/container from Git." || echo "Failed pulling /home/container from Git."
        fi
    else
        # No files exist in resources folder, clone
        echo -e "/home/container is empty.\ncloning files..."
        if [ -z ${GIT_BRANCH} ]; then
            echo -e "Cloning default branch into /home/container."
            git clone ${GIT_ADDRESS} .
        else
            echo -e "Cloning ${GIT_BRANCH} branch into /home/container."
            git clone --single-branch --branch ${GIT_BRANCH} ${GIT_ADDRESS} . && echo "Finished cloning into /home/container from Git." || echo "Failed cloning into /home/container from Git."
        fi
    fi
else
    echo -e "Using Git is disabled."
fi

# set this variable, dotnet needs it even without it it reports to `dotnet --info` it can not start any aplication without this
export DOTNET_ROOT=/usr/share/

# print the dotnet version on startup
printf "\033[1m\033[33mcontainer@pelican~ \033[0mdotnet --version\n"
dotnet --version

# Replace Startup Variables
MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo -e ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}
