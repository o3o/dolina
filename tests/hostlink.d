module tests.hostlink;

import unit_threaded;

import dolina.channel;
import dolina.hostlink;

@UnitTest
void readShouldSendValidString() {
   auto m = mock!IHostLinkChannel;

   m.expect!"write"("@02RD0031000254*\r");
   m.expect!"read";
   m.returnValue!"read"("@02RD0015*");

   auto host = new HostLink(m);
   host.unit = 2;
   host.readDM(31, 2);
   m.verify();
}

@UnitTest
void writeShouldSendValidString() {
   auto chan = mock!IHostLinkChannel;
   chan.expect!"write"("@02WD03020064196458*\r");
   chan.expect!"read";
   chan.returnValue!"read"("@02WD0015*");



   auto host = new HostLink(chan);
   host.unit = 2;
   host.writeDM(302, [100, 6500]);
   chan.verify();
}

@UnitTest
void GivenBigDataWriteShouldSendMultiplePack() {
   auto chan = mock!IHostLinkChannel;

   // non conta cio' che si scrive
   chan.expect!"write";
   chan.expect!"read";
   chan.expect!"write";
   chan.expect!"read";
   chan.expect!"write";
   chan.expect!"read";

   chan.returnValue!"read"(
         "@02WD0015*",
         "@02WD0015*",
         "@02WD0015*"
         );

   auto host = new HostLink(chan);
   host.unit = 2;

   ushort[62] data = 1;
   host.writeDM(302, data);

   chan.verify();
}
