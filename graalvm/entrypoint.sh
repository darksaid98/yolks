#!/bin/bash

#
# Copyright (c) 2021 Matthew Penner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

CONTAINER_DIR="/home/container"
DEFAULT_BRANCH="main"

# Normalize repository URL
normalize_repo_url() {
    local url="$1"

    # Remove any existing credentials (user:token@)
    url=$(echo "$url" | sed 's|https://[^@]*@|https://|')

    # Add .git suffix if not present
    if [[ "$url" != *.git ]]; then
        url="${url}.git"
    fi

    echo "$url"
}

# Construct authenticated URL
construct_auth_url() {
    local repo_url="$1"
    local username="$2"
    local token="$3"

    # Remove https:// prefix
    repo_url="${repo_url#https://}"

    # Construct authenticated URL
    echo "https://${username}:${token}@${repo_url}"
}

# Extract repository info for logging
get_repo_info() {
    local url="$1"
    local normalized_url=$(normalize_repo_url "$url")

    # Extract owner/repo from URL
    local repo_path=$(echo "$normalized_url" | sed 's|https://github.com/||' | sed 's|\.git$||')
    echo "$repo_path"
}

# Check if current directory is a git repository
is_git_repo() {
    [ -d ".git" ] && [ -f ".git/config" ]
}

# Check if repository URLs match (ignores credentials)
urls_match() {
    local url1="$1"
    local url2="$2"

    local normalized1=$(normalize_repo_url "$url1")
    local normalized2=$(normalize_repo_url "$url2")

    [ "$normalized1" = "$normalized2" ]
}

# update git remote URL with new credentials (needed for when a user switches PAT's)
update_remote_url() {
    local new_url="$1"
    echo "Updating remote URL with new credentials..."
    git remote set-url origin "$new_url"
    echo "Remote URL updated successfully"
}

# Apply updates for custom repo
perform_git_update() {
    local branch="$1"
    local repo_info="$2"

    echo ""
    echo "Fetching latest changes from remote..."

    # Check if we have a shallow clone
    local is_shallow=$(git rev-parse --is-shallow-repository 2>/dev/null || echo "false")

    # Switch branches if necessary
    local current_branch=$(git branch --show-current 2>/dev/null || echo "")

    # Check if we need to switch branches
    if [ "$current_branch" != "$branch" ]; then
        echo "Adding remote branch reference for '$branch'..."
        git remote set-branches --add origin "$branch"
    fi

    # Fetch based on whether it's shallow or not
    if [ "$is_shallow" = "true" ]; then
        echo "Detected shallow repository, fetching with depth 1..."
        git fetch --depth 1 origin "$branch"
    else
        echo "Fetching full history..."
        git fetch origin "$branch"
    fi

    echo "Updating local files to match remote branch..."

    if [ "$current_branch" != "$branch" ]; then
        echo "Switching from branch '$current_branch' to '$branch'..."

        # Check if local branch exists
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            echo "Local branch '$branch' exists, checking out..."
            git checkout "$branch"
        else
            echo "Creating and checking out new local branch '$branch'..."
            git checkout -b "$branch" "origin/$branch"
        fi
    fi

    # Deploy changes
    echo "Updating local files to match remote branch..."
    git reset --hard "origin/$branch"

    # Get latest commit info for logging
    local latest_commit=$(git log -1 --oneline 2>/dev/null || echo "unknown")

    echo ""
    echo "✅ Successfully updated repository!"
    echo "Repository: $repo_info"
    echo "Branch: $branch"
    echo "Latest commit: $latest_commit"
}

# Clone custom repo
perform_git_clone() {
    local repo_url="$1"
    local branch="$2"
    local repo_info="$3"

    echo ""
    echo "Cloning repository into container directory..."

    if [ -z "$branch" ]; then
        echo "Cloning default branch..."
        git clone --single-branch --depth 1 "$repo_url" .
    else
        echo "Cloning branch: $branch"
        git clone --single-branch --branch "$branch" --depth 1 "$repo_url" .
    fi

    # Get current branch and latest commit for logging
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local latest_commit=$(git log -1 --oneline 2>/dev/null || echo "unknown")

    echo ""
    echo "✅ Successfully cloned repository!"
    echo "Repository: $repo_info"
    echo "Branch: $current_branch"
    echo "Latest commit: $latest_commit"
}

# Auto update server from git.
perform_git_logic() {
    if [ "${GIT_ENABLED}" == "true" ] || [ "${GIT_ENABLED}" == "1" ]; then
        echo "Git auto-update is enabled"
        echo ""

        # Validate variables
        if [ -z "${GIT_REPOURL}" ]; then
            echo "❌ Error: GIT_REPOURL is not specified"
            exit 1
        fi

        if [ -z "${GIT_USERNAME}" ] || [ -z "${GIT_TOKEN}" ]; then
            echo "❌ Error: GIT_USERNAME or GIT_TOKEN is not specified"
            echo "   Both are required for private repository access"
            exit 1
        fi

        local normalized_repo_url=$(normalize_repo_url "$GIT_REPOURL")
        local auth_repo_url=$(construct_auth_url "$normalized_repo_url" "$GIT_USERNAME" "$GIT_TOKEN")
        local branch="${GIT_BRANCH:-$DEFAULT_BRANCH}"
        local repo_info=$(get_repo_info "$GIT_REPOURL")

        echo "Git Configuration:"
        echo "   Repository: $repo_info"
        echo "   Branch: $branch"
        echo "   Target directory: $CONTAINER_DIR"

        # Check if directory has content
        if [ "$(ls -A .)" ]; then
            echo ""
            echo "Container directory is not empty, checking for existing repository..."

            if is_git_repo; then
                echo "Found existing git repository"

                # Get current remote URL
                local current_remote=$(git config --get remote.origin.url 2>/dev/null || echo "")

                if [ -n "$current_remote" ]; then
                    echo "Current remote: $(normalize_repo_url "$current_remote" | sed 's|https://github.com/||' | sed 's|\.git$||')"

                    # Check if URLs match (ignoring credentials)
                    if urls_match "$current_remote" "$normalized_repo_url"; then
                        echo "Repository URLs match"

                        # Update remote URL with new credentials (handles PAT changes)
                        update_remote_url "$auth_repo_url"

                        # Perform update
                        perform_git_update "$branch" "$repo_info"
                    else
                        echo "❌ Repository mismatch!"
                        echo "   Expected: $repo_info"
                        echo "   Found: $(get_repo_info "$current_remote")"
                        echo ""
                        exit 1
                    fi
                else
                    echo "Could not determine current remote URL"
                    exit 1
                fi
            else
                echo "Directory contains files but is not a git repository"
                perform_git_clone "$auth_repo_url" "$branch" "$repo_info"
            fi
        else
            echo ""
            echo "Container directory is empty, performing initial clone..."
            perform_git_clone "$auth_repo_url" "$branch" "$repo_info"
        fi

        echo ""
        echo "✅ Git auto-update completed successfully!"
        echo "Working directory: $(pwd)"

        # Final verification
        if is_git_repo; then
            local final_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
            echo "Current branch: $final_branch"
        fi

        # Post git stuff
        cd /home/container
    fi
}

perform_git_logic

# Print Java version
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0mjava -version\n"
java -version

# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"
# shellcheck disable=SC2086
eval ${PARSED}
