#!/bin/bash

help() {
        cat <<EOF
    Usage: $0 <command> [arguments]

    Commands:
    check-verilator            : Print the version of the first found Verilator
    verilator-example <DIR>    : Compile and run Verilator example(s) in specified directory
    change-verilator <VERSION> : Change default Verilator to specified version (installs if not present)
    c-compiler-version         : Print versions of default C compiler and GNU Make
    c-compiler-example <DIR>   : Compile and run C/C++ example(s) in specified directory

EOF
}

case "$1" in
    help|--help|-h)
        help
        exit 0
        ;;
    
    check-verilator)
        if command -v verilator >/dev/null 2>&1; then
            verilator --version
        else
            echo "Error: Verilator not found"
            exit 1
        fi
        ;;

    verilator-example)
        run_make_in_dir "$2"
        ;;
    
    change-verilator)
        version="$2"
        if [ -z "$version" ]; then
            die "Version required for change-verilator"
        fi
        echo "Changing Verilator to version $version (installation logic not implemented)"
        # TODO: Implement version switching logic
        ;;
    
    
esac