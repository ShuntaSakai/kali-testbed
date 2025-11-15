@load base/frameworks/notice

# すでに START を出した victim を覚えておく
global synflood_started: set[addr];

hook Notice::notice(n: Notice::Info) : bool
    {
    local now = network_time();

    # --- SYN Flood 開始 ---
    if ( n$note == SynFloodStart )
        {
        # 同じ victim に対して START を何度も出さない
        if ( n$src in synflood_started )
            return T;

        add synflood_started[n$src];

        print fmt("[SYN FLOOD START][0m ts=%.6f victim=%s msg=\"%s\"",
                  now, n$src, n$msg);
        }

    # --- SYN Flood 進行状況 ---
    else if ( n$note == SynFloodStatus )
        {
        print fmt("[SYN FLOOD STATUS][0m ts=%.6f victim=%s n=%d msg=\"%s\"",
                  now, n$src, n$n, n$msg);
        }

    # --- SYN Flood 終了 ---
    else if ( n$note == SynFloodEnd )
        {
        print fmt("[SYN FLOOD END][0m ts=%.6f victim=%s n=%d msg=\"%s\"",
                  now, n$src, n$n, n$msg);

        if ( n$src in synflood_started )
            delete synflood_started[n$src];
        }

    return T;
    }
