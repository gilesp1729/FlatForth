# FlatForth

An x86 32-bit flat model figForth implemntation.

It is based on figForth for IBM PC 2.148 placed in the public domain by the Forth Interest Group.

Derivation:
32-bit protected mode Linux implementation of FIG, with C stubs to do primitive I/O.

Changes:

- builds using Visual Studio in a 32-bit x86 build
- removed macrogeneration and wrote new MASM macros for dictionary entries
- formatting changes to make it MASM-compatible (overcome some of MASM's strange quirks)
- Some new code was rolled back to the old figForth way of doing things (FOR-WORDS/VOCS, FORGET changes, reinstate original VLIST)

Works in progress or contemplated:

* 

* INCLUDE source from files, perhaps removing the old block/screen stuff altogether. Editing source code in blocks is for extreme masochists these days.

* Some degree of integration with VSCode, initially just running terminal I/O to VSCode's terminal window, and later some debugging aids (tracing, breakpoints, watchpoints, and so on)

* A 64-bit (x64 build) version. This is a lot of work for what seems like very little gain, given the motley mess that is the Intel instruction set :-) but it would give vast integer and address range and a doubleword that greatly outperforms floating point on precision.
