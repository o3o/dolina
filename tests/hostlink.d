module tests.hostlink;

import unit_threaded;
import dmocks.mocks;

import dolina.channel;
import dolina.hostlink;

@UnitTest
void read_should_send_valid_string() {
   Mocker m = new Mocker();
   IHostLinkChannel chan = m.mock!(IHostLinkChannel);
   //m.allowUnexpectedCalls(true);
   m.expect(chan.write("@02RD0031000254*\r"));
   m.expect(chan.read()).returns("@02RD0015*");
   // stop registering expected calls
   m.replay();

   auto host = new HostLink(chan);
   host.unit = 2;
   host.read(31, 2);
   m.verify(true // si arrabbia se non si verifica una aspettativa impostata
         , false // ignora se e' stato chiamato un metodo non atteso)
         );
}

@UnitTest
void write_should_send_valid_string() {
   Mocker m = new Mocker();
   IHostLinkChannel chan = m.mock!(IHostLinkChannel);
   m.expect(chan.write("@02WD03020064196458*\r"));
   m.expect(chan.read()).returns("@02WD0015*");
   // stop registering expected calls
   m.replay();

   auto host = new HostLink(chan);
   host.unit = 2;
   host.write(302, [100, 6500]);
   m.verify(true // si arrabbia se non si verifica una aspettativa impostata
         , false // ignora se e' stato chiamato un metodo non atteso)
         );
}

@UnitTest
void given_big_data_Write_should_send_multiple_pack() {
   Mocker m = new Mocker();
   IHostLinkChannel chan = m.mock!(IHostLinkChannel);

   // non conta cio' che si scrive
   chan.write("");
   m.lastCall().ignoreArgs;
   m.lastCall().repeat(3);
   m.expect(chan.read()).returns("@02WD0015*");
   m.lastCall().ignoreArgs;
   m.lastCall().repeat(3);
   m.replay();

   auto host = new HostLink(chan);
   host.unit = 2;

   ushort[62] data = 1;
   host.write(302, data);

   m.verify();

   /*
    *m.verify(true // si arrabbia se non si verifica una aspettativa impostata
    *      , false // ignora se e' stato chiamato un metodo non atteso)
    *      );
    */
}
