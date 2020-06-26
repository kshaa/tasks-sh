# Tasks.sh

It's like a tiny Jenkins for some minor task management.

## Environment
```bash
# Build environment
$ nix-build
# Enter shell w/ tasks.sh
$ nix-shell
```

## Usage
```bash
$ ./tasks.sh help
Usage: TASKS_CONFIG="./path/to/tasks.json" ./tasks.sh ACTION [FILTER]... -- [TASK_PARAMETERS]
Execute shell script tasks with pre/post hooks

Params:
  ACTION              Action to be taken by this script
  FILTER              Filter to specify a subset of task(s)
  TASK_PARAMETERS     Parameters passed to task on execution

Actions:
  get                 List task(s)
  describe            Show verbose information about task(s)
  exec                Execute task(s)
  dump                Pretty print JSON config file
  help                Print this help
  help-config         Print help about config file

Filters:
  name NAME           Filter a specific task by name
  groups GROUPS...    Filter tasks by groups

Environment variables:
  TASKS_CONFIG        Environment variable with path to task
                      configuration file in JSON format, note that
                      if yq is installed, then YAML format is also supported
  DEBUG               If variable is non-zero, then print more
                      information for debugging
  VERBOSE             If variable is non-zero, then print more
                      information regarding task execution
```

```bash
$ ./tasks.sh help-config
./tasks.sh configuration file documentation
Configuration parameters described in JSON path format

.                     <object>    Task configuration
.tasks                <array>     List of configured tasks
.tasks[]              <object>    Individual task specification
.tasks[].name         <string>    Task name, used for info & filtering
.tasks[].description  <string>    Task description, used only for info
.tasks[].groups       <array>     List of groups, which contain this task
.tasks[].groups[]     <string>    Task group, used for info & filtering
.tasks[].task         <string>    The main bash script run by this task, note that
                                  this script can receive parameters, see TASK_PARAMETERS
.tasks[].pre          <string>    Bash script hook run before the execution of the main task
.tasks[].post         <string>    Bash script hook run after the execution of the main task
.tasks[].onfail       <string>    Bash script hook run when any of the aforementioned
                                  hooks or main script fails
```

## Example
```bash
$ ./tasks.sh exec name "d"
Task D is running
```

```bash
$ ./tasks.sh get groups 4
[
  {
    "name": "a",
    "description": "A task",
    "groups": [
      "1",
      "3",
      "4"
    ]
  },
  {
    "name": "b",
    "description": "B task",
    "groups": [
      "1",
      "3",
      "4"
    ]
  },
  {
    "name": "c",
    "description": "C task",
    "groups": [
      "2",
      "3",
      "4"
    ]
  }
]
```