module dolina.util;

import std.array;
import std.bitmanip;
import std.system; // for Endian

/**
* Converts an array into ubyte array.
* 
* Omron stores data in LittleEndian format
*
* Params:  words = array to convert
*			 
*
* Returns: bytes rapresentation
*
*/
ubyte[] toBytes(T)(T[] words) {
   auto buffer = appender!(const(ubyte)[])();
   foreach (dm; words) {
      buffer.append!(T, Endian.littleEndian)(dm);
   }
   return buffer.data;
} unittest {
   import unit_threaded;
   [0x8034].toBytes!ushort().shouldEqual([0x34, 0x80]);

   ushort[] buf = [0x8034, 0x2010];
   buf.toBytes!ushort().shouldEqual([0x34, 0x80, 0x10, 0x20]);
   buf.length.shouldEqual(2);

   [0x8034].toBytes!uint().shouldEqual([0x34, 0x80, 0, 0]);
   [0x010464].toBytes!uint().shouldEqual([0x64, 0x04, 1, 0]);
}

/* 
   FIX: 
ubyte[] readBytes(T)(T[] words) {
   auto buffer = appender!(const(ubyte)[])();
   while (!words.empty) {
      buffer.append!(T, Endian.littleEndian)(words.front);
      words.popFront();
   }
   return buffer.data;
} unittest {
   import unit_threaded;
   [0x8034].readBytes!ushort().shouldEqual([0x34, 0x80]);

   ushort[] buf = [0x8034, 0x2010];
   buf.readBytes!ushort().shouldEqual([0x34, 0x80, 0x10, 0x20]);
   buf.length.shouldEqual(2);

   [0x8034].readBytes!uint().shouldEqual([0x34, 0x80, 0, 0]);
   [0x010464].readBytes!uint().shouldEqual([0x64, 0x04, 1, 0]);
}
*/

/**
 * Takes an array dm of words ($(D ushort)) and converts the first $(D T.sizeof) bytes to
 * $(D T). The array is not consumed.
 * 
 * Params:
 * T = The integral type to convert the first $(D T.sizeof) bytes to.
 * words = The array of word to convert
 * index = The index to start reading from (instead of starting at the front).
 */
T dmPeek(T)(ushort[] words) {
   return dmPeek!T(words, 0);
} unittest {
   import unit_threaded;
   [0x645A, 0x3ffb].dmPeek!float.shouldEqual(1.964F);
}

/++ ditto +/
T dmPeek(T)(ushort[] words, size_t index) {
   enum BYTES_PER_DM = 2;
   ubyte[] buffer = toBytes(words);
   return buffer.peek!(T, Endian.littleEndian)(index * BYTES_PER_DM);
} unittest {
   import unit_threaded;
   [0x645A, 0x3ffb].dmPeek!float(0).shouldEqual(1.964F);
}

/+ fix 
/**
 * Takes an array dm of words ($(D ushort)) and converts the first $(D T.sizeof) bytes to
 * $(D T).  The $(D T.sizeof) bytes which are read are consumed from
 * the array.
 * 
 * Params:
 * T = The integral type to convert the first $(D T.sizeof) bytes to.
 * words = The array of word to convert
 */
T dmRead(T)(ushort[] words) {
   ubyte[] buffer = toBytes(words);
   return buffer.read!(T, Endian.littleEndian);
} unittest {
   import unit_threaded;
   ushort[] buffer = [0x645A, 0x3ffb];
   buffer.length.shouldEqual(2);
   buffer.dmRead!float.shouldEqual(1.964F);
   // FIX:    buffer.length.shouldEqual(0);

   ubyte[] bb = buffer.toBytes();
   bb.length.shouldEqual(4);
   bb.read!(float, Endian.littleEndian).shouldEqual(1.964F);
   bb.length.shouldEqual(0);
}
+/
