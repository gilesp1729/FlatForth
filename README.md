# FlatForth

An i86 32-bit flat model figForth implemntation.

It is based on figForth for IBM PC 2.148 placed in the public domain by the Forth Interest Group.

Derivation:
32-bit protected mode Linux implementation of FIG, with C stubs to do primitive I/O.
  
Changes:
- builds using Visual Studio in a 32-bit i86 build
- removed macrogeneration and wrote new MASM macros for dictionary entries
- formatting changes to make it MASM-compatible (overcome some of MASM's strange quirks)
