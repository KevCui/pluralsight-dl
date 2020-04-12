#!/usr/bin/env bash
#
# Pluralsight course downloader
#
#/ Usage:
#/   ./pluralsight-dl.sh [-s <slug>] [-m <module_num>]
#/
#/ Options:
#/   -s <slug>          Optional, course slug
#/   -m <module_num>    Optional, specific module to download
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
    _CF_FILE="$_SCRIPT_PATH/cf_clearance"
    _LOGIN_JS_SCRIPT="$_SCRIPT_PATH/bin/getjwt.js"
    _CF_JS_SCRIPT="$_SCRIPT_PATH/bin/getCFcookie.js"
    _SOURCE_FILE=".list"

    _CONFIG_FILE="$_SCRIPT_PATH/config"
    [[ ! -f "$_CONFIG_FILE" ]] && print_error "$_CONFIG_FILE doesn't exist!"
    _USERNAME=$(head -1 < "$_CONFIG_FILE" | sed -E 's/[ \t]*$//')
    [[ -z "$_USERNAME" ]] && print_error "Username not found in $_CONFIG_FILE"
    _PASSWORD=$(tail -1 < "$_CONFIG_FILE" | sed -E 's/[ \t]*$//')
    [[ -z "$_PASSWORD" ]] && print_error "Password not found in $_CONFIG_FILE"

    _URL="https://app.pluralsight.com"
    _SEARCH_URL="https://api-us1.cludo.com/api/v3/10000847/10001278/search"
    _SEARCH_SITE_KEY="SiteKey MTAwMDA4NDc6MTAwMDEyNzg6U2VhcmNoS2V5"
    _SEARCH_RESULT_NUM="30"
    _USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$($_CHROME --version | awk '{print $2}') Safari/537.36"

    _MIN_WAIT_TIME="80"
    _MAX_WAIT_TIME="150"
}

set_args() {
    expr "$*" : ".*--help" > /dev/null && usage
    while getopts ":hs:m:" opt; do
        case $opt in
            s)
                _COURSE_SLUG="$OPTARG"
                ;;
            m)
                _MODULE_NUM="$OPTARG"
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
is_file_expired() {
    # $1: file
    # $2: n days
    local o
    o="yes"

    if [[ -f "$1" && -s "$1" ]]; then
        local d n
        d=$(date -d "$(date -r "$1") +$2 days" +%s)
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
    if [[ "$(is_file_expired "$_JWT_FILE" "7")" == "yes" ]]; then
        print_info "Wait for fetching JWT..."
        $_LOGIN_JS_SCRIPT -u "$_USERNAME" -p "$_PASSWORD" -a "$_USER_AGENT" -c "$_CHROME" \
            | $_JQ -r '.[] | select(.name == "PsJwt-production") | .value' \
            | tee "$_JWT_FILE"
    else
        cat "$_JWT_FILE"
    fi
}

get_cf() {
    # $1: url
    if [[ "$(is_file_expired "$_CF_FILE" "1")" == "yes" ]]; then
        print_info "Wait for fetching cf_clearance..."
        $_CF_JS_SCRIPT -u "$1" -a "$_USER_AGENT" -p "$_CHROME" -s \
            | $_JQ -r '.[] | select(.name == "cf_clearance") | .value' \
            | tee "$_CF_FILE"
    else
        cat "$_CF_FILE"
    fi
}

search_course() {
    # $1: search text
    $_CURL -sS --request POST "$_SEARCH_URL" \
        --header "authorization: $_SEARCH_SITE_KEY" \
        --header 'content-type: application/json; charset=UTF-8' \
        --data '{"ResponseType":"json","query":"'"$1"'","facets":{"categories":["course"]},"enableFacetFiltering":"true","page":1,"perPage":"'"$_SEARCH_RESULT_NUM"'","operator":"and"}'
}

download_course_list() {
    # $1: course slug
    local cf f o
    cf=$(get_cf "$_URL")
    f="$_SCRIPT_PATH/${1}"
    mkdir -p "$f"

    o=$($_CURL -sS "$_URL/player?course=$1" \
        --header "cookie: cf_clearance=$cf" \
        --header "user-agent: $_USER_AGENT")

    if [[ "$o" == *"Please complete the security check to access the site."* ]]; then
        print_info "cf error, retry now"
        rm -f "$_CF_FILE"
        download_course_list "$1"
    else
        grep tableOfContents: <<< "$o" | sed -E 's/.*tableOfContents: //' > "$f/$_SOURCE_FILE"
    fi
}

fetch_viewclip() {
    # $1: clip id
    local jwt cf t
    jwt=$(get_jwt)
    cf=$(get_cf "$_URL")
    t=$(shuf -i "${_MIN_WAIT_TIME}"-"${_MAX_WAIT_TIME}" -n 1)
    print_info "Wait for ${t}s"
    sleep "$t"

    o=$($_CURL -sS --limit-rate 1024K --request POST "$_URL/video/clips/v3/viewclip" \
        --header "cookie: PsJwt-production=$jwt; cf_clearance=$cf" \
        --header "content-type: application/json" \
        --header "user-agent: $_USER_AGENT" \
        --data "{\"clipId\":\"$1\",\"mediaType\":\"mp4\",\"quality\":\"1280x720\",\"online\":true,\"boundedContext\":\"course\",\"versionId\":\"\"}")
    if [[ "$o" == *"status\":403"* ]]; then
        print_error "Account blocked! $o"
    fi
    $_JQ -r '.urls[0].url' <<< "$o"
}

download_clip() {
    # $1: course list
    local s
    s=$($_JQ -r '.deprecatedCourseId' < "$1")

    [[ -n ${_MODULE_NUM:-} ]] && print_info "Searching for module $_MODULE_NUM to download..."

    mn=1
    while read -r mt; do
        if [[ -z "${_MODULE_NUM:-}" || "${_MODULE_NUM:-}" == "$mn" ]]; then
        local c mf

        print_info "Find module: $mt"
        mf="$_SCRIPT_PATH/$s/${mn}-${mt}"
        mkdir -p "$mf"

        c=$($_JQ -r '.modules[] | select(.title == $title) | .contentItems' --arg title "$mt" < "$1")

        cn=1
        while read -r ct; do
            local cid l

            print_info "Downloading [$mn $mt - $cn $ct]"
            cid=$($_JQ -r '.[] | select(.title == $title) | .id' --arg title "$ct" <<< "$c")
            l=$(fetch_viewclip "$cid")

            $_CURL -L -g -o "${mf}/${cn}-${ct}.mp4" "$l"

            cn=$((cn+1))
        done <<< "$($_JQ -r '.[].title' <<< "$c")"
        fi

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
        done <<< "$($_JQ -r '.TypedDocuments[].Fields.Title.Value' <<< "$j")"

        echo -n ">> Select which number to download: "
        read -r num
        _COURSE_SLUG=$($_JQ -r '.TypedDocuments[($id | tonumber)].Fields.prodId.Value' --arg id "$((num-1))" <<< "$j")
    fi

    download_course_list "$_COURSE_SLUG"
    download_clip "$_SCRIPT_PATH/$_COURSE_SLUG/$_SOURCE_FILE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
