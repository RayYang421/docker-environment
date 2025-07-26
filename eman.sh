help() {
    cat <<EOF
    
    eman check-verilator            : print the version of the first found Verilator (if there are multiple version of Verilator installed)
    eman verilator-example          : compile and run the Verilator example(s)
    eman change-verilator <VERSION> : change default Verilator to different version. If not installed, install it.

    eman c-compiler-version         : print the version of default C compiler and the version of GNU Make
    eman c-compiler-example         : compile and run the C/C++ example(s)

EOF
}
