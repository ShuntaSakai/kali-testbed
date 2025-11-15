@load base/frameworks/notice

redef enum Notice::Type += {
    PcapReadNotice
};

event zeek_init()
    {
    print "==> Zeek pcap notice test start";
    }

event bro_done()
    {
    NOTICE([$note=PcapReadNotice,
            $msg=fmt("Finished reading pcap at %s", network_time())]);
    }
