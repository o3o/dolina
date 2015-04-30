module dolina.dmrange;

import std.range;
import std.traits; // signed
import std.stdio;
import std.array;

public T pop(T, R)(ref R input) if ((isInputRange!R)
      && is(ElementType!R : const ushort)) {
   static if(isIntegral!T) {
      return popInteger!(R, T.sizeof / 2, isSigned!T)(input);
   } else static if (is(T == float)) {
      return uint2float(popInteger!(R, 2, false)(input));
   } else static if (is(T == double)) {
      return ulong2double(popInteger!(R, 4, false)(input));
   } else {
      static assert(false, "Unsupported type " ~ T.stringof);
   }
} unittest {
   import unit_threaded;

   ushort[] input = [0x1eb8, 0xc19d];
   pop!float(input).shouldEqual(-19.64F);

   input = [0x0, 0xBF00, 0x0, 0x3F00];
   pop!float(input).shouldEqual(-0.5F);
   pop!float(input).shouldEqual(0.5F);

   input = [0x0, 0x0, 0x0, 0x3FE0];
   pop!double(input).shouldEqual(0.5);
   input = [0x0, 0x0, 0x0, 0xBFE0];
   pop!double(input).shouldEqual(-0.5);

   input = [0x00, 0x01, 0x02, 0x03];
   pop!int(input).shouldEqual(0x10000);
   pop!int(input).shouldEqual(0x30002);

   input = [0xFFFF, 0xFFFF, 0xFFFB, 0xFFFB];
   pop!ushort(input).shouldEqual(0xFFFF);
   pop!short(input).shouldEqual(-1);
   pop!ushort(input).shouldEqual(0xFFFB);
   pop!short(input).shouldEqual(-5);


   ushort[] asPeek = [0x645A, 0x3ffb];
   asPeek.pop!float.shouldEqual(1.964F);
} unittest {
   import unit_threaded;

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
}

private auto popInteger(R, int numDM, bool wantSigned)(ref R input) if ((isInputRange!R) 
      && is(ElementType!R : const ushort)) {
   alias T = IntegerLargerThan!(numDM);
   T result = 0;

   for (int i = 0; i < numDM; ++i) {
      result |= ( cast(T)(popDM(input)) << (16 * i) );
   }

   static if (wantSigned) {
      return cast(Signed!T)result;
   }  else {
      return result;
   }
} unittest {
   import unit_threaded;

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

   ushort d = input.front;
   input.popFront();
   return d;
}

void write(T, R)(ref R output, T n) if (isOutputRange!(R, ushort)) {
   static if (isIntegral!T) {
      writeInteger!(R, T.sizeof / 2)(output, n);
   } else static if (is(T == float)) {
      writeInteger!(R, 2)(output, float2uint(n));
   } else static if (is(T == double)) {
      writeInteger!(R, 4)(output, double2ulong(n));
   } else {
      static assert(false, "Unsupported type " ~ T.stringof);
   }
} unittest {
   import unit_threaded;

   ushort[] arr;
   auto app = appender(arr);
   write!float(app, 1.0f);
   write!double(app, 2.0);
   ushort[] expected = [
      0, 0x3f80, 
      0, 0, 0, 0x4000];
   app.data.shouldEqual(expected);
} unittest {
   import std.array;
   import unit_threaded;

   //ushort[] arr;
   //auto app = appender(arr);
   auto app = appender!(const(ushort)[]);
   app.write!ushort(5);
  
   app.data.shouldEqual([5]);
   app.write!float(1.964F);
   app.data.shouldEqual([5, 0x645A, 0x3ffb]);
   app.write!uint(0x1720_8034);
   app.data.shouldEqual([5, 0x645A, 0x3ffb, 0x8034, 0x1720]);
}

private void writeInteger(R, int numDM)(ref R output, IntegerLargerThan!numDM n) if (isOutputRange!(R, ushort)) {
   alias T = IntegerLargerThan!numDM;
   auto u = cast(Unsigned!T)n;
   for (int i = 0; i < numDM; ++i) {
      ushort b = (u >> (i * 16)) & 0xFFFF;
      output.put(b);
   }
}

private float uint2float(uint x) pure nothrow {
   float_uint fi;
   fi.i = x;
   return fi.f;
} unittest {
   import unit_threaded;
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
   import unit_threaded;
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
union float_uint {
   float f;
   uint i;
}

double ulong2double(ulong x) pure nothrow {
   double_ulong fi;
   fi.i = x;
   return fi.f;
} unittest {
   import unit_threaded;
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
   import unit_threaded;
   // see http://gregstoll.dyndns.org/~gregstoll/floattohex/
   double2ulong(0).shouldEqual(0);
   double2ulong(0.5).shouldEqual(0x3fe0000000000000);
   double2ulong(-0.5).shouldEqual(0xbfe0000000000000);
}

union double_ulong {
   double f;
   ulong i;
}
