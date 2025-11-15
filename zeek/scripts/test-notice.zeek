@load base/frameworks/notice

redef enum Notice::Type += {
    TestNotice  # 自分で追加するテスト用の通知タイプ
};

event zeek_init()
    {
    NOTICE([$note=TestNotice,
            $msg="Zeek notice test fired"]);
    }
