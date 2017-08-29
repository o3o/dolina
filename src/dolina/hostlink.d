module dolina.hostlink;

version(unittest) {
   import unit_threaded;
}

import std.array;
import std.conv;
import std.exception;
import std.stdio;
import std.string;

import dolina.channel;

/**
 * Defines the basic HostLink protocol interface.
 */
interface IHostLink {
   /**
    * Reads the contents of specified DM words, starting from the specified
    * word.
    *
    * Params:
    * address = Beginning word address
    * length = Number of words
    */
   ushort[] readDM(const(int) address, const(int) length);

   /**
    * Writes data to the DM area, starting from the specified word.
    *
    * Params:
    * address = Beginning word address
    * data = Words to write
    *
    * Examples:
    * --------------------
    * auto buffer = appender!(const(ushort)[]);
    * buffer.write!float(12.68);
    * buffer.write!ushort(5);
    * plc.writeDM(address, buffer.data);
    * --------------------
    */
   void writeDM(const(int) address, const(ushort)[] data);

   /**
    * Unit number.
    */
   @property int unit();
   @property void unit(int u);

   /**
    * Data memory area size (words)
    */
   @property int dataMemorySize();
}

/**
 * Provides the implementation for HostLink protocol
 */
class HostLink: IHostLink {
   private IHostLinkChannel channel;

   this(IHostLinkChannel channel) {
      assert(channel !is null);
      this.channel = channel;
   }

   @property int dataMemorySize() {
      enum DM_SIZE = 6656;
      return DM_SIZE;
   }

   private int _unit;
   @property int unit() {
      return _unit;
   }

   @property void unit(int u) {
      assert(u >= 0 && u < 32);
      this._unit = u;
   }

   private enum MAX_FRAME_SIZE = 29;
   ushort[] readDM(const(int) address, const(int) length)
      in {
         assert(address >= 0, "negative address");
         assert(length >= 0, "negative lenght");
      } body {
         if (length > MAX_FRAME_SIZE) {
            return readDM(address, MAX_FRAME_SIZE) ~ readDM(address + MAX_FRAME_SIZE, length - MAX_FRAME_SIZE);
         } else if (length <= 0) {
            return null;
         } else {
            string w = getRDString(_unit, address, length);
            channel.write(w);

            string r = channel.read();
            string reply = crop(r);

            immutable(int) err = getErrorCodeFromReply(reply);
            if (err > 0) {
               throw new OmronException(err);
            } else {
               return toDM(reply[6 .. $ - 2]);
            }
         }
      }

   void writeDM(const(int) address, const(ushort)[] data)
      in {
         assert(address >= 0, "negative address");
      } body {
         if (data.length > MAX_FRAME_SIZE) {
            writeDM(address, data[0 .. MAX_FRAME_SIZE]);
            writeDM(address + MAX_FRAME_SIZE, data[MAX_FRAME_SIZE .. $]);
         } else {
            channel.write(getWDString(_unit, address, data));
            string reply = crop(channel.read());

            immutable(int) err = getErrorCodeFromReply(reply);
            if (err > 0) {
               throw new OmronException(err);
            }
         }
      }
}

class NullHostLink: IHostLink {
   ushort[] readDM(const(int) address, const(int) length) {
      return new ushort[length];
   }

   void writeDM(const(int) address, const(ushort)[] data) { }

   private int _unit;
   @property int unit() {
      return _unit;
   }
   @property void unit(int u) {
      _unit = u;
   }

   @property int dataMemorySize() { return 100; }
}

/*
 * Get a string command to read data memory.
 *
 *  String shold be (see chap. 4.9 Omron manual 1E66)
 * ---
 * @|unit|RD|start|length|fcs|*CR
 * ---
 *
 * Params:
 * unit = Node number
 *
 * address = Beginning word address
 * length = Number of words
 *
 * Returns: RD command string
 */
private pure string getRDString(const(int) unit, const(int) address, const(int) length) {
   string send = "@"
      ~ format("%.2d", unit)
      ~ "RD"
      ~ format("%.4d", address)
      ~ format("%.4d", length);

   send ~= fcs(send) ~ "*\r";
   return send;
} unittest {
   getRDString(0, 23, 5).shouldEqual("@00RD0023000552*\r");
   getRDString(0, 100, 2).shouldEqual("@00RD0100000255*\r");
   getRDString(0, 258, 2).shouldEqual("@00RD025800025B*\r");
}

/*
 * Get a string command to write data memory.
 *
 * String shold be (see chap. 4.22 Omron manual 1E66)
 * ---
 * @|unit|WD|address|d0|d1...|fcs|*CR|
 * ---
 *
 * Params:
 * unit = Node number
 * address = Beginning word address
 * length = Number of words
 * data = Words to write
 *
 * Returns: WD command string
 */
private string getWDString(const(int) unit, const(int) address, const(ushort)[] data) {
   string send = "@" ~ format("%.2d", unit) ~ "WD" ~ format("%.4d", address);
   foreach (i; 0 .. data.length) {
      send ~= format("%.4x", data[i]);
   }
   send ~= fcs(send) ~ "*\r";
   return send;
} unittest {
   getWDString(2, 302, [100, 6500]).shouldEqual("@02WD03020064196458*\r");
}

/*
 * Converts a string returned by DM read into an array of `ushort`.
 *
 * The string consists of groups of four characters, each representing a digit in hex.
 * Each group of four characters is the value of a DM
 *
 * Eg. the string representation of `[15, 16, 17]` is  `000F 0010 0011` (spaces are added for readability)
 *
 * Params:  input = string to convert
 * Returns:  Array of converted values
 */
private ushort[] toDM(string input) {
   // std.array.appender:
   // Convenience function that returns an Appender!A object initialized with
   // array.

   auto data = appender!(ushort[])();
   while(input.length > 0) {
      immutable(ushort) x = parseFront(input);
      data.put(x);
      input = input.length >= 4 ? input[4..$] : [];
   }
   return data.data;
} unittest {
   ushort[][string] testCase = [
      "000100020003": [0x1, 0x2, 0x3],
      "00FF8000FFFF": [0xFF, 0x8000, 0xFFFF],
      "5": [0x5],
      "12345": [0x1234, 0x5],
   ];

   foreach (key, value; testCase) {
      toDM(key).shouldEqual(value);
   }
   toDM("").length.shouldEqual(0);
}

/*
 * Converts a DM string representation into a numeric value $(D_CODE ushort).
 *
 * A DM is represented by four characters: if the input string contains more, then
 * `parseFront` converts the first four, if it contains less then all available characters are converted
 *
 * Params:  input = string to convert
 * Returns:  Converted value
 */
private pure ushort parseFront(string input) {
   assert(input.length > 0);

   string front;
   if (input.length >= 4) {
      front = input[0..4];
   } else {
      front = input[0..$];
   }
   // std.conv
   // 16 indica che la stringa e' hex
   return parse!ushort(front, 16);
} unittest {
   parseFront("000F").shouldEqual(15);
   parseFront("000F00FF").shouldEqual(15);
   parseFront("000Fasd").shouldEqual(15);
   parseFront("F").shouldEqual(15);
   parseFront("0F").shouldEqual(15);
   parseFront("0010").shouldEqual(16);
   parseFront("1").shouldEqual(1);
}

/*
 * Computes FCS of message.
 *
 * The FCS is an 8-bit data represented by two ASCII characters (00 to FF).
 *
 * It is a result of Exclusive OR sequentially performed on each character in
 * the message.
 *
 * Params:  msg = Message
 *
 * Returns: Mesage FCS
 */
private pure string fcs(string msg) {
   if (msg.length == 0) {
      return "00";
   } else {
      /*
         std.string.representation:
         Returns the representation of a string, which has the same
         type as the string except the character type is replaced by ubyte,
         ushort, or uint depending on the character width
       */
      immutable(ubyte[]) b = representation(msg);
      int fcs;
      foreach (i; 0 .. b.length) {
         fcs ^= b[i];
      }
      return std.string.format("%.2X", fcs);
   }
} unittest {
   fcs("@02WD00").shouldEqual("51");
   fcs("12").shouldEqual("03");
   fcs("123").shouldEqual("30");
   fcs("0").shouldEqual("30");
   fcs("abc").shouldEqual("60");
   fcs("@00RD00300001").shouldEqual("54");
   fcs("@00RD00300001").shouldEqual("54");
   fcs("@00RD02580002").shouldEqual("5B");
   fcs("").shouldEqual("00");
   fcs(null).shouldEqual("00");
}

/*
 * Get message data.
 *
 * The message data are between the character '@' at the start and '*' at the end.
 *  ---
 *  @|uu|RD|ee|--data --|fc|*|CR
 *  ---
 *  Params:  message = Input message
 *
 *  Returns:
 * The message data if the message is valid, otherwise an empty string
 */
private string crop(string message) {
   import std.regex : match, regex;
   string data;
   if (message.length > 0) {
      string pattern = r"@(?P<core>[^\*]+)\*.*";
      auto m = match(message, regex(pattern));
      if (m) {
         data = m.captures["core"];
      }
   }
   return data;
} unittest {
   crop("@abc*").shouldEqual("abc");
   crop("@abc").shouldEqual("");
   crop("").shouldEqual("");
   crop("xy").shouldEqual("");
   crop("@01RD00").shouldEqual("");
   crop("@01RD00*").shouldEqual("01RD00");
   crop("@01RD00*\n").shouldEqual("01RD00");
   crop("@01RD00*\n@03").shouldEqual("01RD00");
   crop("@00RD000000000056*\r").shouldEqual("00RD000000000056");
}

/*
 * Returns the error code inside the response.
 *
 * In response, there are eight frame characters around error code:
 *
 * ---
 * uu|RD|ee|...dati..|FC|
 * ---
 * with:
 * $(UL
 * $(LI uu: unit no)
 * $(LI RD: read dm)
 * $(LI ee: error code)
 * )
 *
 * Params: reply = PLC reply
 *
 * Returns: error code or 0 if there are no errors.
 */
private int getErrorCodeFromReply(string reply) {
   int err = 1001;
   writeln("errcode imp: ", reply);

   if (reply.length > 5) {
      string code = reply[4..6];
      writeln("errcode: ", code);
      err = parse!int(code, 16);
   }
   return err;
} unittest {
   getErrorCodeFromReply("02RD0015").shouldEqual(0);
   getErrorCodeFromReply("01RD0").shouldEqual(1001);
   getErrorCodeFromReply("01RD0715").shouldEqual(7);
   getErrorCodeFromReply("01RD0A15").shouldEqual(10);
   getErrorCodeFromReply("01RD0B312").shouldEqual(11);
   getErrorCodeFromReply("").shouldEqual(1001);
   getErrorCodeFromReply("01RD").shouldEqual(1001);
   getErrorCodeFromReply("00RD1354").shouldEqual(0x13);
}

class OmronException: Exception {
   this(int errCode) {
      _errCode = errCode;
      super(getErrorMessage(errCode));
   }
   private int _errCode;
   @property int errCode() {
      return _errCode;
   }
}

private pure string getErrorMessage(const(int) errorNr) {
   switch (errorNr) {
      case 0x00: return "Success";
      case 0x01: return "Execution was not possible the PLC is in RUN mode";
      case 0x13: return "Check sum error";
      case 0x14: return "Command format error";
      case 0x15: return "An incorrect data area designation was made for READ or WRITE";
      case 0x18: return "Frame length error";
      case 0x22: return "The specified memory unit does not exists";
      case 0x23: return "The specified memory unit is write protected";
      case 0xA3: return "Aborted due to checksum error in transmit data";
      case 0xA5: return "Aborted due to entry number data error in transmit data";
      case 0xA6: return "Aborted due to frame length error in transmit data";
      case 0x3E8: return "dolina: Frame lenght error in received data"; //10000
      case 0x3E9: return "dolina: Invalid format of error code"; // 1001
      default: return "Unkown error code " ~ to!string(errorNr);
   }
} unittest {
   import std.string : startsWith;
   getErrorMessage(0x44).startsWith("Unkown").shouldBeTrue;
   getErrorMessage(0x13).shouldEqual("Check sum error");
}
