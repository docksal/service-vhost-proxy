#!/usr/bin/env bash

# ----- Helper functions ----- #

is_edge ()
{
	[[ "${SOURCE_BRANCH}" == "develop" ]]
}

is_stable ()
{
	[[ "${SOURCE_BRANCH}" == "master" ]]
}

is_release ()
{
	[[ "${SOURCE_TAG}" != "" ]]
}

# Check whether the current build is for a pull request
is_pr ()
{
	[[ "${EVENT_NAME}" == "pull_request" ]]
}

is_latest ()
{
	[[ "${VERSION}" == "${LATEST_VERSION}" ]]
}

# Tag and push an image
# $1 - source image
# $2 - target image
tag_and_push ()
{
	local source=$1
	local target=$2

	# Base image
	echo "Pushing ${target} image ..."
	docker tag ${source} ${target}
	docker push ${target}
}

# ---------------------------- #

# Extract version parts from release tag
IFS='.' read -a ver_arr <<< "$SOURCE_TAG"
VERSION_MAJOR=${ver_arr[0]#v*}  # 2.7.0 => "2"
VERSION_MINOR=${ver_arr[1]}  # "2.7.0" => "7"

# Set tags if exists
SOFTWARE_VERSION="${SOFTWARE_VERSION:+${SOFTWARE_VERSION}-}"

# Possible docker image tags
# "image:tag" pattern: <image-repo>:<software-version>[-<image-stability-tag>][-<flavor>]
IMAGE_TAG_EDGE="${SOFTWARE_VERSION}edge"  # e.g., [SOFTWARE_VERSION-]edge
IMAGE_TAG_STABLE="${SOFTWARE_VERSION}stable"  # e.g., [SOFTWARE_VERSION-]stable
IMAGE_TAG_RELEASE_MAJOR="${SOFTWARE_VERSION}${VERSION_MAJOR}"  # e.g., [SOFTWARE_VERSION-]2
IMAGE_TAG_RELEASE_MAJOR_MINOR="${SOFTWARE_VERSION}${VERSION_MAJOR}.${VERSION_MINOR}"  # e.g., [SOFTWARE_VERSION-]2.7
IMAGE_TAG_LATEST="latest"

# Skip pull request builds
is_pr && exit

docker login -u "${DOCKER_USER}" -p "${DOCKER_PASS}"

# Push images
if is_edge; then
	tag_and_push ${REPO}:${BUILD_TAG} ${REPO}:${IMAGE_TAG_EDGE}
elif is_stable; then
	tag_and_push ${REPO}:${BUILD_TAG} ${REPO}:${IMAGE_TAG_STABLE}
elif is_release; then
	# Have stable, major, minor tags match
	tag_and_push ${REPO}:${BUILD_TAG} ${REPO}:${IMAGE_TAG_STABLE}
	tag_and_push ${REPO}:${BUILD_TAG} ${REPO}:${IMAGE_TAG_RELEASE_MAJOR}
	tag_and_push ${REPO}:${BUILD_TAG} ${REPO}:${IMAGE_TAG_RELEASE_MAJOR_MINOR}
else
	# Exit if not on develop, master or release tag
	exit
fi

# Special case for the "latest" tag
# Push (base image only) on stable and release builds
if is_latest && (is_stable || is_release); then
	tag_and_push ${REPO}:${BUILD_TAG} ${REPO}:${IMAGE_TAG_LATEST}
fi
