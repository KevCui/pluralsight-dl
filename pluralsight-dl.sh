#!/usr/bin/env bash
#
# Pluralsight course downloader
#
#/ Usage:
#/   ./pluralsight-dl.sh [-s <slug>]
#/
#/ Options:
#/   -s <slug>          Optional, course slug
#/   -h | --help        Display this help message

set -e
set -u

usage() {
    printf "%b\n" "$(grep '^#/' "$0" | cut -c4-)" >&2 && exit 1
}

set_var() {
    _CURL=$(command -v curl)
    _JQ=$(command -v jq)
    _CHROME=$(command -v chromium)

    _SCRIPT_PATH=$(dirname "$0")
    _JWT_FILE="$_SCRIPT_PATH/jwt"
    _LOGIN_JS_SCRIPT="$_SCRIPT_PATH/bin/getjwt.js"
    _SOURCE_FILE=".list"

    _CONFIG_FILE="$_SCRIPT_PATH/config"
    [[ ! -f "$_CONFIG_FILE" ]] && print_error "$_CONFIG_FILE doesn't exist!"
    _USERNAME=$(head -1 < "$_CONFIG_FILE" | sed -E 's/[ \t]*$//')
    [[ -z "$_USERNAME" ]] && print_error "Username not found in $_CONFIG_FILE"
    _PASSWORD=$(tail -1 < "$_CONFIG_FILE" | sed -E 's/[ \t]*$//')
    [[ -z "$_PASSWORD" ]] && print_error "Password not found in $_CONFIG_FILE"

    _URL="https://app.pluralsight.com"
    _USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$($_CHROME --version | awk '{print $2}') Safari/537.36"

    _MIN_WAIT_TIME="80"
    _MAX_WAIT_TIME="150"
}

set_args() {
    expr "$*" : ".*--help" > /dev/null && usage
    while getopts ":hs:" opt; do
        case $opt in
            s)
                _COURSE_SLUG="$OPTARG"
                ;;
            h)
                usage
                ;;
            \?)
                echo "[ERROR] Invalid option: -$OPTARG" >&2
                usage
                ;;
        esac
    done
}

is_jwt_expired() {
    local o
    o="yes"

    if [[ -f "$__FILE" && -s "$_JWT_FILE" ]]; then
        local d n
        d=$(date -d "$(date -r "$_JWT_FILE") +7 days" +%s)
        n=$(date +%s)

        if [[ "$n" -lt "$d" ]]; then
            o="no"
        fi
    fi

    echo "$o"
}

print_info() {
    # $1: info message
    printf "%b\n" "\033[32m[INFO]\033[0m $1" >&2
}

print_error() {
    # $1: error message
    printf "%b\n" "\033[31m[ERROR]\033[0m $1" >&2
    exit 1
}

get_jwt() {
    if [[ "$(is_jwt_expired)" == "yes" ]]; then
        print_info "Wait for fetching JWT..."
        $_LOGIN_JS_SCRIPT -u "$_USERNAME" -p "$_PASSWORD" -a "$_USER_AGENT" -c "$_CHROME" \
            | $_JQ -r '.[] | select(.name == "PsJwt-production") | .value' \
            | tee "$_JWT_FILE"
    else
        cat "$_JWT_FILE"
    fi
}

search_course() {
    # $1: search text
    local jwt
    jwt=$(get_jwt)
    $_CURL -sS "$_URL/search/api/unstable/unified?query=$1&types=video-course&sort=relevance" \
        --header 'x-client-id: 3fc7935d-ff30-4a7f-86f4-f32699378b5e' \
        --header "cookie: PsJwt-production=$jwt"
}

download_course_list() {
    # $1: course slug
    mkdir -p "$_SCRIPT_PATH/${1}"
    $_CURL -sS "$_URL/learner/content/courses/$1" > "$_SCRIPT_PATH/${1}/$_SOURCE_FILE"
}

fetch_viewclip() {
    # $1: clip id
    local jwt t
    jwt=$(get_jwt)
    t=$(shuf -i "${_MIN_WAIT_TIME}"-"${_MAX_WAIT_TIME}" -n 1)
    print_info "Wait for ${t}s"

    sleep "$t"

    $_CURL -sS --request POST "$_URL/video/clips/v3/viewclip" \
        --header "cookie: PsJwt-production=$jwt" \
        --header "content-type: application/json" \
        --data "{\"clipId\":\"$1\",\"mediaType\":\"mp4\",\"quality\":\"1280x720\",\"online\":true,\"boundedContext\":\"course\",\"versionId\":\"\"}" \
        | $_JQ -r '.urls[0].url'
}

download_clip() {
    # $1: course list
    local s
    s=$($_JQ -r '.slug' < "$1")

    mn=1
    while read -r mt; do
        local c mf

        print_info "Find module: $mt"
        mf="$_SCRIPT_PATH/$s/${mn}-${mt}"
        mkdir -p "$mf"

        c=$($_JQ -r '.modules[] | select(.title == $title) | .clips' --arg title "$mt" < "$1")

        cn=1
        while read -r ct; do
            local cid l

            print_info "Downloading $mt - $ct"
            cid=$($_JQ -r '.[] | select(.title == $title) | .clipId' --arg title "$ct" <<< "$c")
            l=$(fetch_viewclip "$cid")

            $_CURL -L -g -o "${mf}/${cn}-${ct}.mp4" "$l"

            cn=$((cn+1))
        done <<< "$($_JQ -r '.[].title' <<< "$c")"

        mn=$((mn+1))
    done <<< "$($_JQ -r '.modules[].title' < "$1")"
}

main() {
    set_args "$@"
    set_var

    if [[ -z "${_COURSE_SLUG:-}" ]]; then
        local j t i
        echo -n ">> Enter keyword to search courses: "
        read -r name
        j=$(search_course "$name")

        i=1
        while read -r l; do
            printf "%b\n" "\033[33m[$i]\033[0m $l"
            i=$((i+1))
        done <<< "$($_JQ -r '.search."video-course".hits[].csTitle' <<< "$j")"

        echo -n ">> Select which number to download: "
        read -r num
        _COURSE_SLUG=$($_JQ -r '.search."video-course".hits[($id | tonumber)].csSlug' --arg id "$((num-1))" <<< "$j")
    fi

    download_course_list "$_COURSE_SLUG"
    download_clip "$_SCRIPT_PATH/$_COURSE_SLUG/$_SOURCE_FILE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
