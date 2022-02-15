#!/usr/bin/python3
# Copyright 2013 oyatsukai.com

import sys
import os
import struct

def usage(r=0):
    print( "Usage: patch_word <filename> <decimal-byte-offset> <hex-word>" )
    print( "" )
    exit(r)


if "__main__" == __name__:

    args = sys.argv;
    if 4 != len(args):
        usage(1)

    filename = args[1]
    offset = int(args[2])
    value = int(args[3], 16)

    print( "file to patch  : %s" % filename )
    print( "  offset       : %d (0x%x)" % (offset, offset) )

    with open(filename, "r+b") as f:

        f.seek(offset)
        curbytes = f.read(4)
        cur = struct.unpack("<I", curbytes)
        print( "  original value: 0x%x" % cur )

        f.seek(offset)
        newbytes = struct.pack("<I", value)
        f.write(newbytes)

    print( "  new value    : %d (0x%x)" % (value, value) )
