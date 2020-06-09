#!/usr/bin/env bash

# Environment variables
CONFIG="${TASKS_CONFIG:-tasks.json}"
DEBUG="${DEBUG}"
VERBOSE="${VERBOSE}"

# Named parameters
SCRIPT="$0"
ACTION="$1"
FILTER="$2"

# Script usage documentation
help() {
    echo "Usage: TASKS_CONFIG=\"./path/to/tasks.json\" $SCRIPT ACTION [FILTER]... -- [TASK_PARAMETERS]"
    echo "Execute shell script tasks with pre/post hooks"
    echo
    echo "Params:"
    echo "  ACTION              Action to be taken by this script"
    echo "  FILTER              Filter to specify a subset of task(s)"
    echo "  TASK_PARAMETERS     Parameters passed to task on execution"
    echo
    echo "Actions:"
    echo "  get                 List task(s)"
    echo "  describe            Show verbose information about task(s)"
    echo "  exec                Execute task(s)"
    echo "  dump                Pretty print JSON config file"
    echo "  help                Print this help"
    echo "  help-config         Print help about config file"
    echo
    echo "Filters:"
    echo "  name NAME           Filter a specific task by name"
    echo "  groups GROUPS...    Filter tasks by groups"
    echo
    echo "Environment variables:"
    echo "  TASKS_CONFIG        Environment variable with path to task"
    echo "                      configuration file in JSON format, note that"
    echo "                      if yq is installed, then YAML format is also supported"
    echo "  DEBUG               If variable is non-zero, then print more"
    echo "                      information for debugging"
    echo "  VERBOSE             If variable is non-zero, then print more"
    echo "                      information regarding task execution"
}

# Script configuration documentation
help_config() {
    echo "$SCRIPT configuration file documentation"
    echo "Configuration parameters described in JSON path format"
    echo
    echo ".                     <object>    Task configuration"
    echo ".tasks                <array>     List of configured tasks"
    echo ".tasks[]              <object>    Individual task specification"
    echo ".tasks[].name         <string>    Task name, used for info & filtering"
    echo ".tasks[].description  <string>    Task description, used only for info"
    echo ".tasks[].groups       <array>     List of groups, which contain this task"
    echo ".tasks[].groups[]     <string>    Task group, used for info & filtering"
    echo ".tasks[].task         <string>    The main bash script run by this task, note that"
    echo "                                  this script can receive parameters, see TASK_PARAMETERS"
    echo ".tasks[].pre          <string>    Bash script hook run before the execution of the main task"
    echo ".tasks[].post         <string>    Bash script hook run after the execution of the main task"
}

# Validation: Check if jq exists
# Source: https://stackoverflow.com/a/26759734
if ! [ -x "$(command -v jq)" ]
then
  echo 'Error: jq is not installed.' >&2
  exit 1
fi

# Validation: Check if yq exists
# Source: https://stackoverflow.com/a/26759734
if ! [ -x "$(command -v yq)" ] && [ -n "$VERBOSE" ]
then
  echo 'Warn: yq is not installed.' >&2
fi

# Validation: Action is required
if [ -z "$ACTION" ]
then
    echo "Error: missing action parameter"
    echo "Run '$SCRIPT help' for help"
    exit 1
fi

# Print help if needed
if [ "$ACTION" == "help" ]
then
    help
    exit 0
elif [ "$ACTION" == "help-config" ]
then
    help_config
    exit 0
fi

# Validation: Config file must exist
if [ ! -f "$CONFIG" ]
then
    echo "Error: task configuration file '$CONFIG' doesn't exist"
    echo "Run '$SCRIPT help' for help"
    exit 1
fi

# Validation: If filtering is used, filter value is required
if [ -n "$FILTER" ] && [ -z "$3" ]
then
    echo "Error: Filter '$FILTER' is used, but no filter value provided"
    exit 1
fi

# Ingress: Read JSON or YAML (if possible)
if [ -x "$(command -v yq)" ]
then
    CONFIG_JSON="$(cat $CONFIG | yq  '.' -r)"
else
    CONFIG_JSON="$(cat $CONFIG | jq '.' -r)"
fi

# Filtering: Subset tasks based on provided filters and their values
TASKS_JSON="$(echo $CONFIG_JSON | jq '.tasks' -r)"
if [ "$FILTER" == "name" ]
then
    NAME="$3"
    JQ_QUERY="echo \$TASKS_JSON | jq '[ .[] | select(.name == \"$NAME\") ]'"
    if [ -n "$DEBUG" ]; then echo "Debug: Task JQ filter: $JQ_QUERY"; fi
    TASKS_JSON="$(eval $JQ_QUERY)"
    if [ "$4" == "--" ]
    then
        shift
        shift
        shift
        shift
    fi
elif [ "$FILTER" == "groups" ]
then
    shift
    shift
    for GROUP in "$@"
    do
        shift
        if [ "$GROUP" == "--" ]
        then 
            break
        else
            JQ_QUERY="echo \$TASKS_JSON | jq '[ .[] | select(.groups[]? | contains(\"$GROUP\")) ]'"
            if [ -n "$DEBUG" ]; then echo "Debug: Task JQ filter: $JQ_QUERY"; fi
            TASKS_JSON="$(eval $JQ_QUERY)"
        fi
    done
elif [ "$FILTER" == "--" ]
then
    shift
    shift
elif [ -n "$FILTER" ]
then
    echo "Error: Unknown filter '$FILTER'"
    echo "Run '$SCRIPT help' for help"
    exit 1
fi

# Run appropriate command based on parameters
if [ "$ACTION" == "get" ]
then
    echo $TASKS_JSON | jq '[.[] | { name: .name, description: .description, groups: .groups }]'
elif [ "$ACTION" == "describe" ]
then
    echo $TASKS_JSON | jq -r
elif [ "$ACTION" == "exec" ]
then
    for TASK_JSON in $(echo "$TASKS_JSON" | jq -r '.[] | @base64')
    do
        # Source: https://www.starkandwayne.com/blog/bash-for-loop-over-json-array-using-jq/
        _jq() {
            SHORT_JQ_QUERY="$1"
            JQ_QUERY="echo \$TASK_JSON | base64 --decode | jq -r \"$SHORT_JQ_QUERY\""
            if [ -n "$DEBUG" ]; then echo "Debug: Task attribute filter: $JQ_QUERY" >&2; fi
            echo "$(eval $JQ_QUERY)"
        }

        # Prepare task environment
        NAME="$(_jq '.name')"
        PRE="$(_jq '.pre')"
        TASK="$(_jq '.task')"
        POST="$(_jq '.post')"
        ONFAIL="$(_jq '.onfail')"

        # Run task and its hooks
        export ERROR_CODE=""
        if [ -z "$ERROR_CODE" ] && [ "$PRE" != "null" ]
        then
            if [ -n "$VERBOSE" ]; then echo "# Running '$NAME' pre-hook"; fi
            if ! eval "$PRE"
            then
                ERROR_CODE="$?"
            fi
        fi

        if [ -z "$ERROR_CODE" ] && [ "$TASK" != "null" ]
        then
            if [ -n "$VERBOSE" ]; then echo "# Running '$NAME' task"; fi
            if ! eval "$TASK"
            then
                ERROR_CODE="$?"
            fi
        fi
        
        if [ -z "$ERROR_CODE" ] && [ "$POST" != "null" ]
        then
            if [ -n "$VERBOSE" ]; then echo "# Running '$NAME' post-hook"; fi
            if ! eval "$POST"
            then
                ERROR_CODE="$?"
            fi
        fi

        if [ -n "$ERROR_CODE" ] && [ "$ONFAIL" != "null" ]
        then
            if [ -n "$VERBOSE" ]; then echo "# Running '$NAME' fail-hook"; fi
            eval "$ONFAIL"
        fi

        if [ -n "$VERBOSE" ]; then echo; fi
    done
elif [ "$ACTION" == "dump" ]
then
    echo $CONFIG_JSON | jq -r
fi