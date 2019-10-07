module tests.channel;

import dolina.channel;
import serial.device;
import unit_threaded;

@UnitTest
void writeShouldWriteOnSerial() {
   class SerialMockW {
      bool writeDone;
      void write(const(void[]) arr) {
         writeDone = true;
      }
      size_t read(void[] arr) {
         ubyte[] b = cast(ubyte[])arr;
         b[0] = 0x40;
         b[1] = 0x41;
         b[2] = 0x0D;
         return 3;
      }
   }
   auto serial = new SerialMockW();


   IHostLinkChannel chan = new HLChannel!SerialMockW(serial);
   assert(!serial.writeDone);
   chan.write("a");
   assert(serial.writeDone);

}

@UnitTest
void readShouldReadOnSerial() {
   auto serial = new SerialMock();

   IHostLinkChannel chan = new HLChannel!SerialMock(serial);
   string r = chan.read();
   import std.stdio;
   writefln("-->%s ",  r);
}

class SerialMock {
   bool writeDone;
   void write(const(void[]) arr) {
      writeDone = true;
   }

   private ubyte[] buf = [0x40, 0x30, 0x0D];
   private size_t ptr;
   size_t read(void[] arr) {
      ubyte[] b = cast(ubyte[])arr;
      b[0] = buf[ptr++];
      //arr = cast(void[])buf[ptr++];
      //*arr.ptr = buf[0];
         //cast(void[])buf[ptr++];
      return 1;
   }
}
