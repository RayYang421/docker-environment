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

die() {
    echo "Error: $1" >&2
    help
    exit 1
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
    
    c-compiler-version)
        if command -v gcc >/dev/null 2>&1; then
            echo "GCC Version:"
            gcc --version | head -n 1
        else
            echo "Error: GCC not found"
        fi
        if command -v make >/dev/null 2>&1; then
            echo -e "\nGNU Make Version:"
            make --version | head -n 1
        else
            echo "Error: GNU Make not found"
        fi
        ;;
    
    c-compiler-example)
        run_make_in_dir "$2"
        ;;
    *)
        echo "Error: Unknown command: $1"
        help
        exit 1
        ;;

esac