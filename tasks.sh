#!/usr/bin/env bash

# Environment variables
CONFIG="${TASKS_CONFIG:-tasks.json}"
DEBUG="${DEBUG}"
VERBOSE="${VERBOSE}"
if [ -n "$DEBUG" ]
then
    # In debug mode, just print as much as possible
    set -x
fi

# Named parameters
## Constants
SCRIPT="$0"
ACTION="$1"
FILTER="$2"

## Action parameter is always first and was captured
if [[ "$#" -ge 1 ]]
then
    shift
fi

## Everything else is some extra parameter
EXTRA_VALUES=("${@:-}")

## Split extra parameters into filters & task parameters
FILTER_VALUES=()
TASK_PARAMETERS=()
PARSING_TASK_PARAMETERS=""
for EXTRA_VALUE in "${EXTRA_VALUES[@]}"
do
    if [ "$EXTRA_VALUE" == "--" ]
    then 
        PARSING_TASK_PARAMETERS="1"
        shift
        continue
    fi
    
    if [ -z "$PARSING_TASK_PARAMETERS" ]
    then
        if [ "$EXTRA_VALUE" != "groups" ] && [ "$EXTRA_VALUE" != "name" ]
        then
            FILTER_VALUES+=("$EXTRA_VALUE")
        fi
        shift
    else
        TASK_PARAMETERS+=("$EXTRA_VALUE")
    fi
done

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
    echo ".tasks[].onfail       <string>    Bash script hook run when any of the aforementioned"
    echo "                                  hooks or main script fails"
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

# Validation: Action is correct
if [ "$(echo '[ "get", "describe", "exec", "dump", "help", "help-config" ]' | jq '.[] | select(contains("'$ACTION'"))')" == "" ]
then
    echo "Error: Unknown action '$ACTION'" >&2
    echo "Run '$SCRIPT help' for help" >&2
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

# Validation: Filter is correct
if [ -n "$FILTER" ] && [ "$(echo '[ "name", "groups", "--" ]' | jq --arg filter "$FILTER" '.[] | select(contains($filter))')" == "" ]
then
    echo "Error: Invalid filter '$FILTER'" >&2
    echo "Run '$SCRIPT help' for help" >&2
    exit 1
fi

# Validation: If filtering is used, filter value is required
if [ -n "$FILTER" ] && [ -z "${FILTER_VALUES[0]}" ] && [ "$FILTER" != "--" ]
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

# Dump config if needed
if [ "$ACTION" == "dump" ]
then
    echo $CONFIG_JSON | jq -r .
    exit 0
fi

# Filtering: Subset tasks based on provided filters and their values
filter_tasks() {
    TASKS_JSON="${1:-}"
    if [ "$FILTER" == "name" ]
    then
        NAME="${FILTER_VALUES[0]:-}"
        TASKS_JSON="$(echo "$TASKS_JSON" | jq --arg name "$NAME" -r '[ .[] | select(.name == $name) ]')"
    elif [ "$FILTER" == "groups" ]
    then
        for GROUP in "${FILTER_VALUES[@]}"; do
            TASKS_JSON="$(echo "$TASKS_JSON" | jq --arg group "$GROUP" -r '[ .[] | select(.groups[]? | contains($group)) ]')"
        done
    fi

    echo "$TASKS_JSON" | jq -r .
}

# Run task with eval or through execution
task_run() {
    TASK="$1"
    if [ -f "$TASK" ]
    then
        $TASK "${TASK_PARAMETERS[@]}"
    else
        TMPSCRIPT="$(mktemp)"
        echo "$TASK" > $TMPSCRIPT
        bash "$TMPSCRIPT" "${TASK_PARAMETERS[@]}"
        RETURN_CODE="$?"
        rm $TMPSCRIPT
    fi

    return $RETURN_CODE
}

# Run appropriate command based on parameters
TASKS_JSON="$(echo $CONFIG_JSON | jq -r .tasks)"
TASKS_JSON="$(filter_tasks "$TASKS_JSON")"
if [ "$ACTION" == "get" ]
then
    echo $TASKS_JSON | jq '[ .[] | { name, description, groups } ]'
elif [ "$ACTION" == "describe" ]
then
    echo $TASKS_JSON | jq -r
elif [ "$ACTION" == "exec" ]
then
    LENGTH="$(echo "$TASKS_JSON" | jq length)" && START=0 && END="$(($LENGTH - 1))"
    for (( INDEX = $START; INDEX <= $END; INDEX++ ))
    do
        TASK_JSON="$(echo "$TASKS_JSON" | jq .[$INDEX])"

        # Prepare task environment
        NAME="$(echo "$TASK_JSON" | jq -r .name)"
        PRE="$(echo "$TASK_JSON" | jq -r .pre)"
        TASK="$(echo "$TASK_JSON" | jq -r .task)"
        POST="$(echo "$TASK_JSON" | jq -r .post)"
        ONFAIL="$(echo "$TASK_JSON" | jq -r .onfail)"

        # Run task and its hooks
        export PRE_OUT="$(mktemp)"
        export TASK_OUT="$(mktemp)"
        export POST_OUT="$(mktemp)"

        ## Pre task
        export PRE_CODE="0"
        if [ -n "$VERBOSE" ]; then echo "# Running '$NAME' pre-hook"; fi
        if [ "$PRE" != "null" ]
        then
            task_run "$PRE" 2>&1 | tee $PRE_OUT
            export PRE_CODE="${PIPESTATUS[0]}"
            if [ "$PRE_CODE" != "0" ] && [ -n "$VERBOSE" ]; then echo "# '$NAME' pre-hook failed w/ code '$PRE_CODE'"; fi
            echo "Exited with '$PRE_CODE'" >> $PRE_OUT
        else
            if [ -n "$VERBOSE" ]; then echo "# '$NAME' pre-hook not defined, skipping it"; fi
        fi

        ## Task
        export TASK_CODE="0"
        if [ "$PRE_CODE" == "0" ]
        then
            if  [ "$TASK" != "null" ]
            then
                if [ -n "$VERBOSE" ]; then echo "# Running '$NAME' task"; fi
                task_run "$TASK" 2>&1 | tee $TASK_OUT
                export TASK_CODE="$?"
                if [ "$TASK_CODE" != "0" ] && [ -n "$VERBOSE" ]; then echo "# '$NAME' task failed w/ code '$TASK_CODE'"; fi
                echo "Exited with '$TASK_CODE'" >> $TASK_OUT
            else
                if [ -n "$VERBOSE" ]; then echo "# '$NAME' task not defined, skipping it"; fi
            fi
        else
            if [ -n "$VERBOSE" ]; then echo "# '$NAME' pre-hook failed, skipping task"; fi
        fi

        ## Post task
        export POST_CODE="0"
        if [ "$POST" != "null" ]
        then
            if [ -n "$VERBOSE" ]; then echo "# Running '$NAME' post-hook"; fi
            task_run "$POST" 2>&1 | tee $POST_OUT
            export POST_CODE="$?"
            echo "Exited with '$POST_CODE'" >> $POST_OUT
        else
            if [ -n "$VERBOSE" ]; then echo "# '$NAME' post-hook not defined, skipping it"; fi
        fi

        rm $PRE_OUT
        rm $TASK_OUT
        rm $POST_OUT
        
        if [ -n "$VERBOSE" ]; then echo; fi
    done
fi