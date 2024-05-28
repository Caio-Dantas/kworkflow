# Checkpatch is a useful tool provided by Linux, and the main goal of the code
# in this file is to handle this script in a way to make this tool easier for
# users.

include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

declare -gA options_values

# Runs checkpatch in the given path, which might be a file or directory.
#
# @FILE_OR_DIR_CHECK Target path for running checkpatch script
function codestyle_main()
{
  local path
  local flag
  local checkpatch_options="${configurations[checkpatch_opts]}"
  local -r original_working_dir="$PWD"
  local kernel_root
  local checkpatch
  local cmd_script
  local checked_snippet_temp_file

  parse_codestyle_options "$@"
  if [[ "$?" != 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  flag=${options_values['TEST_MODE']}
  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  flag=${flag:-'SILENT'}
  # TODO: Note that codespell file is not specified yet because of the poluted
  # output. It could be nice if we can add another option just for this sort
  # of check.

  path="${options_values['PATH']}"
  path=${path:-'.'}
  if [[ ! -d "$path" && ! -f "$path" ]]; then
    complain "Invalid path: ${path}"
    return 2 # ENOENT
  fi

  # Get realpath for using inside checkpatch
  path="$(realpath "$path")"

  # Try to find kernel root at given path
  kernel_root="$(find_kernel_root "$path")"
  if [[ -z "$kernel_root" ]]; then
    # Fallback: try to find kernel root at working path
    kernel_root="$(find_kernel_root "$original_working_dir")"
  fi

  # Check if kernel root was found
  if [[ -z "$kernel_root" ]]; then
    complain 'Neither the given path nor the working path is in a kernel tree.'
    return 22 # EINVAL
  fi

  # Build a list of file to apply check patch
  FLIST=$(find "$path" -type f ! -name '*\.mod\.c' | grep "\.[ch]$")

  say "Running checkpatch.pl on: ${path}"
  say "$SEPARATOR"

  # Define different rules for patch and files
  if is_a_patch "$path"; then
    FLIST="$path"
  else
    checkpatch_options="--terse ${checkpatch_options} --file"
  fi

  checkpatch=$(join_path "$kernel_root" 'scripts/checkpatch.pl')
  cmd_script="perl ${checkpatch} ${checkpatch_options}"

  [[ -n "${options_values['START_LINE']}" ]] && start_line=${options_values['START_LINE']}
  [[ -n "${options_values['END_LINE']}" ]] && end_line=${options_values['END_LINE']}

  if [[ -n "$start_line" || -n "$end_line" ]]; then
    handle_line_range_option "$start_line" "$end_line" "$path" "$checked_snippet_temp_file"
    if [[ "$?" == 22 ]]; then
      return 22
    else
      FLIST="$checked_snippet_temp_file"
    fi
  fi

  for current_file in $FLIST; do
    file="$current_file"

    if [[ ! -e "$file" ]]; then
      printf '%s\n' "$file does not exist."
      continue
    fi

    cmd_manager "$flag" "$cmd_script $file"
    [[ "$?" != 0 ]] && say "$SEPARATOR"
  done

  if [[ -n "$checked_snippet_temp_file" ]]; then
    is_safe_path_to_remove "$checked_snippet_temp_file"
    if [[ "$?" == 0 ]]; then
      rm "$checked_snippet_temp_file"
    fi
  fi
}

# Returns:
# In case of successful returns 0 and write the temporary file content on $4,
# otherwise, return 22
function handle_line_range_option()
{
  start_line="$1"
  end_line="$2"
  path="$3"
  checked_snippet_temp_file="$4"

  local file_last_line

  if [[ ! -f "$path" ]]; then
    complain "Invalid path using --start-line or --end-line options: ${path}"
    return 22 # EINVAL
  fi
  
  if [[ -n "$start_line" ]]; then
    # Check if --start-line is used with a valid number
    if [[ ! "$start_line" =~ ^[0-9]+$ || "$start_line" -lt 1 ]]; then
      complain "Invalid value for start-line option: ${start_line}"
      return 22 # EINVAL
    fi
  else
    start_line=1
  fi

  file_last_line=$(wc --lines < "$path")
  if [[ -n "$end_line" ]]; then
    # Check if --end-line is used with a valid number
    if [[ ! "$end_line" =~ ^[0-9]+$ || "$end_line" -gt "$file_last_line" ]]; then
      complain "Invalid value for end-line option: ${end_line}"
      return 22 # EINVAL
    fi
  else
    end_line="$file_last_line"
  fi

  create_snippet_temp_file "$start_line" "$end_line" "$path" "$checked_snippet_temp_file"
 
  # Write the line interval to the temporary file and return it
  sed --quiet "${start_line},${end_line}p" "$path" >> "$checked_snippet_temp_file"
  return 0
}

# Write the temporary file with blank lines and SPDX License Identifier if needed
function create_snippet_temp_file()
{
  start_line=$1
  end_line=$2
  path=$3
  checked_snippet_temp_file=$4

  local file_suffix
  local blank_lines

  # Create a temporary file with the line interval and SPDX License Identifier if needed
  file_suffix=".${path#*.}"
  checked_snippet_temp_file=$(mktemp --suffix "$file_suffix" --tmpdir="$PWD")

  if [[ "$start_line" != '1' ]]; then
    printf '%s\n' '// SPDX-License-Identifier: TEMPFILE' > "$checked_snippet_temp_file"
    ((blank_lines = start_line - 2))
    yes '' | head --lines "$blank_lines" >> "$checked_snippet_temp_file"
  fi
}

# This function gets raw data and based on that fill out the options values to
# be used in another function.
#
# Return:
# In case of successful return 0, otherwise, return 22.
function parse_codestyle_options()
{
  local long_options='verbose,help,start-line:,end-line:'
  local short_options='h'
  local options

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw diff' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['VERBOSE']=''
  options_values['TEST_MODE']=''
  options_values['START_LINE']=''
  options_values['END_LINE']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      --start-line)
        options_values['START_LINE']="$2"
        shift 2
        ;;
      --end-line)
        options_values['END_LINE']="$2"
        shift 2
        ;;
      TEST_MODE)
        options_values['TEST_MODE']='TEST_MODE'
        shift
        ;;
      --help | -h)
        codestyle_help "$1"
        exit
        ;;
      --)
        shift
        ;;
      *)
        options_values['PATH']="$1"
        shift
        ;;
    esac
  done
}

function codestyle_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'codestyle'
    return
  fi
  printf '%s\n' 'kw codestyle:' \
    '  codestyle [<dir>|<file>|<patch>] - Use checkpatch on target' \
    '  codestyle (--verbose) [<dir>|<file>|<patch>] - Show detailed output' \
    '  codestyle (--start-line <line>) - Set line where the script will start checkpatch' \
    '  codestyle (--end-line <line>) - Set line where the script will end checkpatch'
}

load_kworkflow_config
