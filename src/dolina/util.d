/**
* Utility functions to convert DM
*/
module dolina.util;

import std.array;
import std.bitmanip;
import std.system; // for Endian
import std.range;

/**
* Bytes per each DM. 
*
* A DM is a `ushort`, so each DM has 2 bytes
*/
enum BYTES_PER_DM = 2;

/**
* Converts an array of DM into ubyte array.
* 
* Omron stores data in LittleEndian format.
*
* Examples:
* --------------------
*  ushort[] buf = [0x8034, 0x2010];
*  assert(buf.toBytes!ushort() == [0x34, 0x80, 0x10, 0x20]);
* --------------------
*
* Params:  words = array to convert
*
* Returns: bytes rapresentation
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

/**
* Converts an array of bytes into DM array.
* 
* Params:  bytes = array to convert
*
* Returns: DM rapresentation
*/
ushort[] toDM(ubyte[] bytes) {
   ushort[] dm;
   while (bytes.length >= BYTES_PER_DM) {
      dm ~= bytes.read!(ushort, Endian.littleEndian);
   }
   if (bytes.length > 0) {
      dm ~= bytes[0];
   }
   return dm;
} unittest {
   import unit_threaded;
   [0x10].toDM().shouldEqual([0x10]);
   [0, 0xAB].toDM().shouldEqual([0xAB00]);
   [0x20, 0x0].toDM().shouldEqual([0x20]);
   [0x10, 0x20, 0x30, 0x40, 0x50].toDM().shouldEqual([0x2010, 0x4030, 0x50]);
}


/**
 * Takes an array of DM (words ushort)) and converts the first `T.sizeof / 2`
 * DM to `T`. 
 * The array is not consumed.
 * 
 * Params:
 * T = The integral type to convert the first `T.sizeof / 2` words to.
 * words = The array of DM to convert
 *
 * Examples:
 * --------------------
 * assert([0x645A, 0x3ffb].peekDM!float() == 1.964F);
 * --------------------
 */
T peekDM(T)(ushort[] words) {
   return peekDM!T(words, 0);
} unittest {
   import unit_threaded;
   [0x645A, 0x3ffb].peekDM!float.shouldEqual(1.964F);
}

/**
 * Takes an array of DM (`ushort`) and converts the first `T.sizeof / 2`
 * DM to `T` starting from index `index`. 
 *
 * The array is not consumed.
 * 
 * Params:
 * T = The integral type to convert the first `T.sizeof / 2` words to.
 * words = The array of DM to convert
 * index = The index to start reading from (instead of starting at the front).
 */
T peekDM(T)(ushort[] words, size_t index) {
   ubyte[] buffer = toBytes(words);
   return buffer.peek!(T, Endian.littleEndian)(index * BYTES_PER_DM);
} unittest {
   import unit_threaded;
   [0x645A, 0x3ffb].peekDM!float(0).shouldEqual(1.964F);
   [0, 0, 0x645A, 0x3ffb].peekDM!float(2).shouldEqual(1.964F);
   [0, 0, 0x645A, 0x3ffb].peekDM!float(0).shouldEqual(0);
   [0x80, 0, 0].peekDM!ushort(0).shouldEqual(128);
   [0xFFFF].peekDM!short(0).shouldEqual(-1);
   [0xFFFF].peekDM!ushort(0).shouldEqual(65535);
   [0xFFF7].peekDM!ushort(0).shouldEqual(65527);
   [0xFFF7].peekDM!short(0).shouldEqual(-9);
   [0xFFFB].peekDM!short(0).shouldEqual(-5);
   [0xFFFB].peekDM!ushort(0).shouldEqual(65531);
   [0x8000].peekDM!short(0).shouldEqual(-32768);
}

/**
 * Takes an array of DM (`ushort`) and converts the first `T.sizeof / 2`
 * DM to `T`. 
 *
 * The `T.sizeof / 2` words which are read are consumed from
 * the array.
 * 
 * Params:
 * T = The integral type to convert the first `T.sizeof / 2` words to.
 * words = The array of words to convert
 */
T readDM(T)(ref ushort[] words) if (T.sizeof > 1) {
   enum NO_OF_DM = T.sizeof / BYTES_PER_DM;

   ushort[NO_OF_DM] dm;
   foreach(ref e; dm) {
      e = words.front;
      words.popFront();
   }

   const ubyte[T.sizeof] bytes = dm.toBytes();
   return littleEndianToNative!T(bytes);
} unittest {
   import unit_threaded;
   ushort[] buffer = [0x645A, 0x3ffb];
   buffer.length.shouldEqual(2);
   buffer.readDM!float.shouldEqual(1.964F);
   buffer.length.shouldEqual(0);

   ushort[] shortBuffer = [0x645A];
   shortBuffer.length.shouldEqual(1);
   shortBuffer.readDM!float().shouldThrow!Error;

   ushort[] bBuffer = [0x0001, 0x0002, 0x0003];
   bBuffer.length.shouldEqual(3);

   bBuffer.readDM!ushort.shouldEqual(1);
   bBuffer.length.shouldEqual(2);

   bBuffer.readDM!ushort.shouldEqual(2);
   bBuffer.length.shouldEqual(1);

   bBuffer.readDM!ushort.shouldEqual(3);
   bBuffer.length.shouldEqual(0);
}
