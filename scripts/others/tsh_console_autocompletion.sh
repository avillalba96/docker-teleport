#!/bin/bash

_tsh_console() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"

    # Autocompletar el primer argumento
    if [[ ${cur} == -* || ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$(cat /tmp/tsh_clusters 2>/dev/null)" -- ${cur}))
        return 0
    fi

    # Autocompletar el segundo argumento
    if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$(cat /tmp/tsh_users 2>/dev/null)" -- ${cur}))
        return 0
    fi

    # Autocompletar el tercer argumento
    if [[ ${COMP_CWORD} -eq 3 ]]; then
        COMPREPLY=($(compgen -W "$(cat /tmp/tsh_nodes 2>/dev/null)" -- ${cur}))

        return 0
    fi

}

complete -F _tsh_console tsh_console