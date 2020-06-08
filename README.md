# Tasks.sh

It's like a tiny Jenkins for some minor task management.

## Usage
```bash
$ ./tasks.sh help
Usage: TASKS_CONFIG="./path/to/tasks.json" ./tasks.sh ACTION [FILTER]...
Execute shell script tasks with pre/post hooks

Params:
  ACTION              Action to be taken by this script
  FILTER              Filter to specify a subset of task(s)

Actions:
  get                 List task(s)
  describe            Show verbose information about task(s)
  exec                Execute task(s)
  dump                Pretty print JSON config file
  help                Print this help

Filters:
  name NAME           Filter a specific task by name
  groups GROUPS...    Filter tasks by groups

Environment variables:
  TASKS_CONFIG        Environment variable with path to task
                      configuration file in JSON format
  DEBUG               If variable is non-zero, then print more
                      information for debugging
  VERBOSE             If variable is non-zero, then print more
                      information regarding task execution
```

## Example
```bash
$ ./tasks.sh exec name "d"
Task D is running
```
