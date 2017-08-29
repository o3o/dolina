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
