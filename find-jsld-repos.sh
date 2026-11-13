#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_NAME=${0##*/}
readonly STYLE_RESET=$'\033[0m'
readonly STYLE_TITLE=$'\033[1;36m'
readonly STYLE_SUCCESS=$'\033[1;32m'
readonly STYLE_ERROR=$'\033[1;31m'
readonly STYLE_WARNING=$'\033[1;33m'
readonly LICENSE_PATTERN='\(RimoChan/Je-Suis-Le-Deluge\)|^[[:space:]]*RimoChan Revolution License'
scan_file=''

color_text() {
	local style=$1 text=$2
	if [[ -n ${NO_COLOR+x} || ! -t 1 ]]; then
		printf '%s' "$text"
	else
		printf '%s%s%s' "$style" "$text" "$STYLE_RESET"
	fi
}

usage() {
	printf '%s\n' "$(color_text "$STYLE_TITLE" "Usage: $SCRIPT_NAME [DIRECTORY]")"
	printf '\nRecursively find Git working trees using the Je-Suis-Le-Deluge license.\n'
	printf 'Default directory: ~/cargo/repo\n'
	printf 'Checks root LICENSE/LICENCE files (including extensions), COPYING and UNLICENSE.\n'
	printf 'Nested repositories and Git worktrees are included; symlinks are not followed.\n'
	printf 'License files are checked as they exist on disk, including untracked files.\n'
	printf 'Only matching repositories are listed; totals include non-matches and invalid entries.\n'
	printf '\nExamples:\n  %s\n  %s /path/to/repos\n' "$SCRIPT_NAME" "$SCRIPT_NAME"
}

die() {
	printf '%s\n' "$(color_text "$STYLE_ERROR" "Error: $*")" >&2
	exit 1
}

cleanup() {
	if [[ -n $scan_file && -f $scan_file ]]; then
		rm -f -- "$scan_file"
	fi
}

scan_repository() {
	local repo_root=$1 match_number=$2 license_file filename grep_status matched=0 heading
	for license_file in "$repo_root"/*; do
		[[ -f $license_file && ! -L $license_file ]] || continue
		filename=${license_file##*/}
		case "$filename" in
		[Ll][Ii][Cc][Ee][Nn][Ss][Ee] | [Ll][Ii][Cc][Ee][Nn][Ss][Ee].* | \
			[Ll][Ii][Cc][Ee][Nn][Cc][Ee] | [Ll][Ii][Cc][Ee][Nn][Cc][Ee].* | \
			[Cc][Oo][Pp][Yy][Ii][Nn][Gg] | [Cc][Oo][Pp][Yy][Ii][Nn][Gg].* | \
			[Uu][Nn][Ll][Ii][Cc][Ee][Nn][Ss][Ee] | [Uu][Nn][Ll][Ii][Cc][Ee][Nn][Ss][Ee].*) ;;
		*) continue ;;
		esac
		if grep -Ei -- "$LICENSE_PATTERN" "$license_file" >/dev/null; then
			if [[ $matched -eq 0 ]]; then
				printf -v heading '[%02d] USES je-suis-le-deluge: %q' "$match_number" "${repo_root##*/}"
				printf '\n%s\n' "$(color_text "$STYLE_SUCCESS" "$heading")"
				printf '     Repository : %q\n' "$repo_root"
			fi
			printf '     License    : %q\n' "$filename"
			matched=1
		else
			grep_status=$?
			[[ $grep_status -eq 1 ]] || die "Cannot read license: $license_file"
		fi
	done
	[[ $matched -eq 1 ]]
}

main() {
	local search_dir=${HOME:?HOME is not set}/cargo/repo command_name git_entry repo_root
	local scanned=0 matched=0 skipped=0
	case ${1:-} in
	--help | -h)
		usage
		return 0
		;;
	--) shift ;;
	-*)
		usage >&2
		die "Unknown option: $1"
		;;
	esac
	[[ $# -le 1 ]] || {
		usage >&2
		die 'Expected at most one directory'
	}
	if [[ $# -eq 1 ]]; then
		search_dir=$1
	fi
	[[ -d $search_dir ]] || die "Directory does not exist: $search_dir"
	search_dir=$(cd -- "$search_dir" && pwd -P)
	for command_name in find git grep mktemp rm; do
		command -v "$command_name" >/dev/null 2>&1 || die "Required command not found: $command_name"
	done
	scan_file=$(mktemp "${TMPDIR:-/tmp}/find-jsld-repos.XXXXXXXX")
	trap cleanup EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	printf '%s\n' "$(color_text "$STYLE_TITLE" '============================================================')"
	printf '%s\n' "$(color_text "$STYLE_TITLE" '  je-suis-le-deluge LICENSE SCAN')"
	printf '%s\n' "$(color_text "$STYLE_TITLE" '============================================================')"
	printf 'Scan directory : %q\n' "$search_dir"
	printf 'Scope          : root license files in Git working trees\n'
	printf 'Results below  : repositories using je-suis-le-deluge only\n'
	find "$search_dir" -name .git \( -type d -o -type f \) -print0 -prune >"$scan_file" || die 'Repository discovery failed'
	while IFS= read -r -d '' git_entry; do
		repo_root=${git_entry%/.git}
		if ! git -C "$repo_root" rev-parse --show-toplevel >/dev/null 2>&1; then
			printf '%s\n' "$(color_text "$STYLE_WARNING" "Warning: Skipping invalid Git working tree: $repo_root")" >&2
			skipped=$((skipped + 1))
			continue
		fi
		scanned=$((scanned + 1))
		if scan_repository "$repo_root" "$((matched + 1))"; then
			matched=$((matched + 1))
		fi
	done <"$scan_file"
	if [[ $matched -eq 0 ]]; then
		printf '\n%s\n' "$(color_text "$STYLE_WARNING" 'No repositories using je-suis-le-deluge were found.')"
	fi
	printf '\n%s\n' "$(color_text "$STYLE_TITLE" '============================================================')"
	printf '%s\n' "$(color_text "$STYLE_TITLE" '  SCAN SUMMARY')"
	printf '%s\n' "$(color_text "$STYLE_TITLE" '============================================================')"
	printf '%s\n' "$(color_text "$STYLE_SUCCESS" "  USING je-suis-le-deluge   : $matched repositories")"
	printf '  No je-suis-le-deluge match: %d repositories\n' "$((scanned - matched))"
	printf '  Checked      : %d repositories\n' "$scanned"
	printf '  Skipped      : %d invalid Git entries\n' "$skipped"
}

main "$@"
