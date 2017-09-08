/**
 * Utility functions to convert DM
 */
module dolina.util;
version(unittest) {
   import unit_threaded;
}

import std.bitmanip : read;
import std.system : Endian; // for Endian
import std.range;

/**
 * Bytes per each DM.
 *
 * A DM is a $(Dushort), so each DM has 2 bytes.
 */
enum BYTES_PER_DM = 2;

/**
 * Converts an array of type T into an ubyte array.
 *
 * Omron stores data in LittleEndian format.
 *
 * Params:  input = array of type T to convert
 *
 * Returns: An array of ubyte
 */
ubyte[] toBytes(T)(T[] input) {
   import std.array : appender;
   import std.bitmanip : append;

   auto buffer = appender!(const(ubyte)[])();
   foreach (dm; input) {
      buffer.append!(T, Endian.littleEndian)(dm);
   }
   return buffer.data.dup;
}
///
unittest {
   [0x8034].toBytes!ushort().shouldEqual([0x34, 0x80]);

   ushort[] buf = [0x8034, 0x2010];
   buf.toBytes!ushort().shouldEqual([0x34, 0x80, 0x10, 0x20]);
   buf.length.shouldEqual(2);

   [0x8034].toBytes!uint().shouldEqual([0x34, 0x80, 0, 0]);
   [0x010464].toBytes!uint().shouldEqual([0x64, 0x04, 1, 0]);
}

/**
 * Converts an array of bytes into DM (ushort) array.
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
}

///
unittest {
   [0x10].toDM().shouldEqual([0x10]);
   [0, 0xAB].toDM().shouldEqual([0xAB00]);
   [0x20, 0x0].toDM().shouldEqual([0x20]);
   [0x10, 0x20, 0x30, 0x40, 0x50].toDM().shouldEqual([0x2010, 0x4030, 0x50]);
}

/**
 * Takes an array of DM $(D ushort) and converts the first $(D T.sizeof / 2)
 * DM to $(D T).
 * The array is **not** consumed.
 *
 * Params:
 *  T = The integral type to convert the first `T.sizeof / 2` words to.
 *  words = The array of DM to convert
 */
T peekDM(T)(ushort[] words) {
   return peekDM!T(words, 0);
}
///
unittest {
   ushort[] words = [0x645A, 0x3ffb];
   words.peekDM!float.shouldEqual(1.964F);
   words.length.shouldEqual(2);

   ushort[] odd = [0x645A, 0x3ffb, 0xffaa];
   odd.peekDM!float.shouldEqual(1.964F);
   odd.length.shouldEqual(3);
}

/**
 * Takes an array of DM ($(D ushort)) and converts the first $(D T.sizeof / 2)
 * DM to $(D T) starting from index *index*.
 *
 * The array is **not** consumed.
 *
 * Params:
 * T = The integral type to convert the first `T.sizeof / 2` DM to.
 * words = The array of DM to convert
 * index = The index to start reading from (instead of starting at the front).
 */
T peekDM(T)(ushort[] words, size_t index) {
   import std.bitmanip : peek;
   ubyte[] buffer = toBytes(words);
   return buffer.peek!(T, Endian.littleEndian)(index * BYTES_PER_DM);
}
///
unittest {
   [0x645A, 0x3ffb].peekDM!float(0).shouldEqual(1.964F);
   [0, 0, 0x645A, 0x3ffb].peekDM!float(2).shouldEqual(1.964F);
   [0, 0, 0x645A, 0x3ffb].peekDM!float(0).shouldEqual(0);
   [0x80, 0, 0].peekDM!ushort(0).shouldEqual(128);
   [0xFFFF].peekDM!short(0).shouldEqual(-1);
   [0xFFFF].peekDM!ushort(0).shouldEqual(65_535);
   [0xFFF7].peekDM!ushort(0).shouldEqual(65_527);
   [0xFFF7].peekDM!short(0).shouldEqual(-9);
   [0xFFFB].peekDM!short(0).shouldEqual(-5);
   [0xFFFB].peekDM!ushort(0).shouldEqual(65_531);
   [0x8000].peekDM!short(0).shouldEqual(-32_768);
}

/**
 * Converts ushort value into BDC format
 *
 * Params:
 *  dec = ushort in decimal format
 *
 * Returns: BCD value
 */
ushort toBCD(ushort dec) {
   enum ushort MAX_VALUE = 9999;
   enum ushort MIN_VALUE = 0;
   if ((dec > MAX_VALUE) || (dec < MIN_VALUE)) {
      throw new Exception("Decimal out of range (should be 0..9999)");
   } else {
      ushort bcd;
      enum ushort NUM_BASE = 10;
      ushort i;
      for(; dec > 0; dec /= NUM_BASE) {
         ushort rem = cast(ushort)(dec % NUM_BASE);
         bcd += cast(ushort)(rem << 4 * i++);
      }
      return bcd;
   }
}
///
unittest {
   0.toBCD().shouldEqual(0);
   10.toBCD().shouldEqual(0x10);
   34.toBCD().shouldEqual(52);
   127.toBCD().shouldEqual(0x127);
   110.toBCD().shouldEqual(0x110);
   9999.toBCD().shouldEqual(0x9999);
   9999.toBCD().shouldEqual(39_321);
}

/**
 * Converts BCD value into decimal format
 *
 * Params:
 *  dec = ushort in BCD format
 *
 * Returns: decimal value
 */
ushort fromBCD(ushort bcd) {
   enum int NO_OF_DIGITS = 8;
   enum ushort MAX_VALUE = 0x9999;
   enum ushort MIN_VALUE = 0;
   if ((bcd > MAX_VALUE) || (bcd < MIN_VALUE)) {
      throw new Exception("BCD out of range (should be 0..39321)");
   } else {
      ushort dec;
      ushort weight = 1;
      foreach (j; 0 .. NO_OF_DIGITS) {
         dec += cast(ushort)((bcd & 0x0F) * weight);
         bcd = cast(ushort)(bcd >> 4);
         weight *= 10;
      }
      return dec;
   }
}
///
unittest {
   0.fromBCD().shouldEqual(0);

   (0x22).fromBCD().shouldEqual(22);
   (34).fromBCD().shouldEqual(22);
   // 17bcd
   (0b0001_0111).fromBCD().shouldEqual(17);
   295.fromBCD().shouldEqual(127);
   39_321.fromBCD().shouldEqual(9_999);
   (0x9999).fromBCD().shouldEqual(9_999);
}

/**
 * Takes an input range of DM ($(D ushort)) and converts the first $(D T.sizeof / 2)
 * DM's to $(D T).
 * The array is consumed.
 *
 * Params:
 * T = The integral type to convert the first `T.sizeof / 2` DM to.
 * input = The input range of DM to convert
 */
T pop(T, R)(ref R input) if ((isInputRange!R)
      && is(ElementType!R : const ushort)) {
   import std.traits : isIntegral, isSigned;
   static if(isIntegral!T) {
      return popInteger!(R, T.sizeof / 2, isSigned!T)(input);
   } else static if (is(T == float)) {
      return uint2float(popInteger!(R, 2, false)(input));
   } else static if (is(T == double)) {
      return ulong2double(popInteger!(R, 4, false)(input));
   } else {
      static assert(false, "Unsupported type " ~ T.stringof);
   }
}

/**
 * $(D pop!float) example
 */
unittest {
   ushort[] asPeek = [0x645A, 0x3ffb];
   asPeek.pop!float.shouldEqual(1.964F);
   asPeek.length.shouldEqual(0);

   // float.sizeOf is 4bytes => 2 DM
   ushort[] input = [0x1eb8, 0xc19d];
   input.length.shouldEqual(2);
   pop!float(input).shouldEqual(-19.64F);
   input.length.shouldEqual(0);

   input = [0x0, 0xBF00, 0x0, 0x3F00];
   input.pop!float.shouldEqual(-0.5F);
   pop!float(input).shouldEqual(0.5F);
}

/**
 * $(D pop!double) examples.
 *
 * A double has size 8 bytes => 4DM
 */
unittest {
   ushort[] input = [0x0, 0x0, 0x0, 0x3FE0];
   input.length.shouldEqual(4);

   pop!double(input).shouldEqual(0.5);
   input.length.shouldEqual(0);

   input = [0x0, 0x0, 0x0, 0xBFE0];
   pop!double(input).shouldEqual(-0.5);

   input = [0x00, 0x01, 0x02, 0x03];
   input.length.shouldEqual(4);
   pop!int(input).shouldEqual(0x10000);
   input.length.shouldEqual(2);
   pop!int(input).shouldEqual(0x30002);
   input.length.shouldEqual(0);
}

/**
 * pop!ushort and short examples
 */
unittest {
   ushort[] input = [0xFFFF, 0xFFFF, 0xFFFB, 0xFFFB];
   pop!ushort(input).shouldEqual(0xFFFF);
   pop!short(input).shouldEqual(-1);
   pop!ushort(input).shouldEqual(0xFFFB);
   pop!short(input).shouldEqual(-5);
} unittest {
   ushort[] input = [0x1eb8, 0xc19d
      , 0x0, 0xBF00, 0x0, 0x3F00
      , 0x0, 0x0, 0x0, 0x3FE0
      , 0x0, 0x0, 0x0, 0xBFE0
      , 0x00, 0x01, 0x02, 0x03
      , 0xFFFF, 0xFFFF, 0xFFFB, 0xFFFB];

   pop!float(input).shouldEqual(-19.64F);
   pop!float(input).shouldEqual(-0.5F);
   pop!float(input).shouldEqual(0.5F);

   pop!double(input).shouldEqual(0.5);
   pop!double(input).shouldEqual(-0.5);

   pop!int(input).shouldEqual(0x10000);
   pop!int(input).shouldEqual(0x30002);

   pop!ushort(input).shouldEqual(0xFFFF);
   pop!short(input).shouldEqual(-1);
   pop!ushort(input).shouldEqual(0xFFFB);
   pop!short(input).shouldEqual(-5);
} unittest {
   ushort[] shortBuffer = [0x645A];
   shortBuffer.length.shouldEqual(1);
   shortBuffer.pop!float().shouldThrow!Exception;

   ushort[] bBuffer = [0x0001, 0x0002, 0x0003];
   bBuffer.length.shouldEqual(3);

   bBuffer.pop!ushort.shouldEqual(1);
   bBuffer.length.shouldEqual(2);

   bBuffer.pop!ushort.shouldEqual(2);
   bBuffer.length.shouldEqual(1);

   bBuffer.pop!ushort.shouldEqual(3);
   bBuffer.length.shouldEqual(0);
}

/**
 * Takes an input range of DM ($(D ushort)) and converts the first $(D numDM)
 * DM's to $(D T).
 * The array is consumed.
 *
 * Params:
 *  R = The integral type of innput range
 *  numDM = Number of DM to convert
 *  wantSigned = Get signed value
 *  input = The input range of DM to convert
 */
private auto popInteger(R, int numDM, bool wantSigned)(ref R input) if ((isInputRange!R)
      && is(ElementType!R : const ushort)) {
   import std.traits : Signed;
   alias T = IntegerLargerThan!(numDM);
   T result = 0;

   foreach (i; 0 .. numDM) {
      result |= ( cast(T)(popDM(input)) << (16 * i) );
   }

   static if (wantSigned) {
      return cast(Signed!T)result;
   }  else {
      return result;
   }
} unittest {
   ushort[] input = [0x00, 0x01, 0x02, 0x03];
   popInteger!(ushort[], 2, false)(input).shouldEqual(0x10000);
   popInteger!(ushort[], 2, false)(input).shouldEqual(0x30002);
   input.length.shouldEqual(0);
   input = [0x01, 0x02, 0x03, 0x04];
   popInteger!(ushort[], 3, false)(input).shouldEqual(0x300020001);

   input = [0x01, 0x02];
   popInteger!(ushort[], 3, false)(input)
      .shouldThrow!Exception;

   input = [0x00, 0x8000];
   popInteger!(ushort[], 2, false)(input).shouldEqual(0x8000_0000);

   input = [0xFFFF, 0xFFFF];
   popInteger!(ushort[], 2, true)(input).shouldEqual(-1);
   input = [0xFFFF, 0xFFFF, 0xFFFB, 0xFFFB];
   popInteger!(ushort[], 1, false)(input).shouldEqual(0xFFFF);
   popInteger!(ushort[], 1, true)(input).shouldEqual(-1);
   popInteger!(ushort[], 1, false)(input).shouldEqual(0xFFFB);
   popInteger!(ushort[], 1, true)(input).shouldEqual(-5);
}

private template IntegerLargerThan(int numDM) if (numDM > 0 && numDM <= 4) {
   static if (numDM == 1) {
      alias IntegerLargerThan = ushort;
   } else static if (numDM == 2) {
      alias IntegerLargerThan = uint;
   } else {
      alias IntegerLargerThan = ulong;
   }
}

private ushort popDM(R)(ref R input) if ((isInputRange!R) && is(ElementType!R : const ushort)) {
   if (input.empty) {
      throw new Exception("Expected a ushort, but found end of input");
   }

   const(ushort) d = input.front;
   input.popFront();
   return d;
}

/**
 * Writes numeric type *T* into a output range of *ushort*.
 *
 * Params:
 * n = The numeric type to write into output range
 * output = The output range of DM to convert
 *
 * Examples:
 * --------------------
 * ushort[] arr;
 * auto app = appender(arr);
 * write!float(app, 1.0f);
 *
 *
 * auto app = appender!(const(ushort)[]);
 * app.write!ushort(5);
 * app.data.shouldEqual([5]);
 * --------------------
 */
void write(T, R)(ref R output, T n) if (isOutputRange!(R, ushort)) {
   import std.traits : isIntegral;
   static if (isIntegral!T) {
      writeInteger!(R, T.sizeof / 2)(output, n);
   } else static if (is(T == float)) {
      writeInteger!(R, 2)(output, float2uint(n));
   } else static if (is(T == double)) {
      writeInteger!(R, 4)(output, double2ulong(n));
   } else {
      static assert(false, "Unsupported type " ~ T.stringof);
   }
}
/**
 * Write float and double
 */
unittest {
   ushort[] arr;
   auto app = appender(arr);
   write!float(app, 1.0f);

   app.write!double(2.0);

   ushort[] expected = [
      0, 0x3f80,
      0, 0, 0, 0x4000];
   app.data.shouldEqual(expected);
}

/**
 * Write ushort and int
 */
unittest {
   import std.array : appender;

   auto app = appender!(const(ushort)[]);
   app.write!ushort(5);
   app.data.shouldEqual([5]);

   app.write!float(1.964F);
   app.data.shouldEqual([5, 0x645A, 0x3ffb]);

   app.write!uint(0x1720_8034);
   app.data.shouldEqual([5, 0x645A, 0x3ffb, 0x8034, 0x1720]);
}

private void writeInteger(R, int numDM)(ref R output, IntegerLargerThan!numDM n) if (isOutputRange!(R, ushort)) {
   import std.traits : Unsigned;
   alias T = IntegerLargerThan!numDM;
   auto u = cast(Unsigned!T)n;
   foreach (i; 0 .. numDM) {
      immutable(ushort) b = (u >> (i * 16)) & 0xFFFF;
      output.put(b);
   }
}

private float uint2float(uint x) pure nothrow {
   float_uint fi;
   fi.i = x;
   return fi.f;
} unittest {
   // see http://gregstoll.dyndns.org/~gregstoll/floattohex/
   uint2float(0x24369620).shouldEqual(3.959212E-17F);
   uint2float(0x3F000000).shouldEqual(0.5F);
   uint2float(0xBF000000).shouldEqual(-0.5F);
   uint2float(0x0).shouldEqual(0);
   uint2float(0x419D1EB8).shouldEqual(19.64F);
   uint2float(0xC19D1EB8).shouldEqual(-19.64F);
   uint2float(0x358637bd).shouldEqual(0.000001F);
   uint2float(0xb58637bd).shouldEqual(-0.000001F);
}

private uint float2uint(float x) pure nothrow {
   float_uint fi;
   fi.f = x;
   return fi.i;
} unittest {
   // see http://gregstoll.dyndns.org/~gregstoll/floattohex/
   float2uint(3.959212E-17F).shouldEqual(0x24369620);
   float2uint(.5F).shouldEqual(0x3F000000);
   float2uint(-.5F).shouldEqual(0xBF000000);
   float2uint(0x0).shouldEqual(0);
   float2uint(19.64F).shouldEqual(0x419D1EB8);
   float2uint(-19.64F).shouldEqual(0xC19D1EB8);
   float2uint(0.000001F).shouldEqual(0x358637bd);
   float2uint(-0.000001F).shouldEqual(0xb58637bd);
}

// read/write 64-bits float
private union float_uint {
   float f;
   uint i;
}

double ulong2double(ulong x) pure nothrow {
   double_ulong fi;
   fi.i = x;
   return fi.f;
} unittest {
   // see http://gregstoll.dyndns.org/~gregstoll/floattohex/
   ulong2double(0x0).shouldEqual(0);
   ulong2double(0x3fe0000000000000).shouldEqual(0.5);
   ulong2double(0xbfe0000000000000).shouldEqual(-0.5);
}

private ulong double2ulong(double x) pure nothrow {
   double_ulong fi;
   fi.f = x;
   return fi.i;
} unittest {
   // see http://gregstoll.dyndns.org/~gregstoll/floattohex/
   double2ulong(0).shouldEqual(0);
   double2ulong(0.5).shouldEqual(0x3fe0000000000000);
   double2ulong(-0.5).shouldEqual(0xbfe0000000000000);
}

private union double_ulong {
   double f;
   ulong i;
}
