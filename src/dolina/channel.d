/**
 * Defines channel objects layer.
 *
 * A channel is a message delivery mechanism that forwards a message from a
 * sender to one receiver.
 */
module dolina.channel;

import std.exception;
import serial.device;
/**
 * Defines a basic HostLink channel
 */
interface IHostLinkChannel {
   /**
    * Reads a message from channel
    *
    * Returns: message read
    */
   string read();

   /**
    * Writes a message on channel
    *
    * Params:  message = The message being sent on the channel.
    */
   void write(string message);
}

/**
 * Channel based on serial RS232 communication
 */
class HostLinkChannel: IHostLinkChannel {
   private SerialPort serialPort;
   this(SerialPort serialPort) {
      enforce(serialPort !is null);
      this.serialPort = serialPort;
   }

   string read() {
      enum START = 0x40; // @
      enum END = 0x0D;  // CR
      bool inside;

      ubyte[1] buffer;
      ubyte[] reply;
      ubyte b;
      do {
         immutable(size_t) length = serialPort.read(buffer);
         if (length > 0) {
            b = buffer[0];
            if (b == START) {
               inside = true;
            }
            if (inside) {
               reply ~= b;
            }
         }

      } while (b != END);
      return cast(string)(reply).idup;
   }

   void write(string message) {
      serialPort.write(cast(void[])message);
   }
}

// https://forum.dlang.org/thread/kpvypzrhwbeizzkkamkc@forum.dlang.org
//if ( __traits(hasMember, S, "read"))
class HLChannel(S=SerialPort): IHostLinkChannel {
   static assert( __traits(hasMember, S, "read"));
   static assert( __traits(hasMember, S, "write"));

   private S serialPort;
   this(S serialPort) {
      enforce(serialPort !is null);
      this.serialPort = serialPort;
   }

   string read() {
      enum START = 0x40; // @
      enum END = 0x0D;  // CR
      bool inside;

      ubyte[1] buffer;
      ubyte[] reply;
      ubyte b;
      do {
         immutable(size_t) length = serialPort.read(buffer);
         if (length > 0) {
            b = buffer[0];
            if (b == START) {
               inside = true;
            }
            if (inside) {
               reply ~= b;
            }
         }

      } while (b != END);
      return cast(string)(reply).idup;
   }

   void write(string message) {
      serialPort.write(cast(void[])message);
   }
}

unittest {
   class SerialMockW {
      bool writeDone;
      void write(const(void[]) arr) {
         writeDone = true;
      }
      size_t read(void[] arr) {
         return 3;
      }
   }
   auto serial = new SerialMockW();

   IHostLinkChannel chan = new HLChannel!SerialMockW(serial);
   assert(!serial.writeDone);
   chan.write("a");
   assert(serial.writeDone);
}
unittest {
   class SerialMockR {
      void write(const(void[]) arr) {}

      private ubyte[] buf = [0x39, 0x40, 0x41, 0x0D, 0x43, 0x44];
      private size_t ptr;
      size_t read(void[] arr) {
         ubyte[] b = cast(ubyte[])arr;
         b[0] = buf[ptr++];
         return 1;
      }
   }

   auto serial = new SerialMockR();

   IHostLinkChannel chan = new HLChannel!SerialMockR(serial);
   string msg = chan.read();
   assert(msg.length == 3);
   assert(msg == "@A" ~ '\r');
}
