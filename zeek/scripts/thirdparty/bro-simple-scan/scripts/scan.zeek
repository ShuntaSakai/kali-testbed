##! TCP Scan detection.

# ..Authors: Justin Azoff
#            All the authors of the old scan.bro

@load base/frameworks/notice
@load base/utils/time
#@ifndef(Site::darknet_mode)
#@load packages/bro-is-darknet
#@endif

module Scan;

export {
	redef enum Notice::Type += {
		## Address scans detect that a host appears to be scanning some
		## number of destinations on a single port. This notice is
		## generated when more than :bro:id:`Scan::scan_threshold`
		## unique hosts are seen over the previous
		## :bro:id:`Scan::scan_interval` time range.
		Address_Scan,

		## Port scans detect that an attacking host appears to be
		## scanning a single victim host on several ports.  This notice
		## is generated when an attacking host attempts to connect to
		## :bro:id:`Scan::scan_threshold`
		## unique ports on a single host over the previous
		## :bro:id:`Scan::scan_interval` time range.
		Port_Scan,

		## Random scans detect that an attacking host appears to be
		## scanning multiple victim hosts on several ports.  This notice
		## is generated when an attacking host attempts to connect to
		## :bro:id:`Scan::scan_threshold`
		## unique hosts and ports over the previous
		## :bro:id:`Scan::scan_interval` time range.
		Random_Scan,
	};

	## An individual scan destination
	type Attempt: record {
		victim: addr;
		scanned_port: port;
	};

	## Information tracked for each scanner
	type Scan_Info: record {
		first_seen: time;
		attempts: set[Attempt];
		port_counts: table[port] of count;
		dark_hosts: set[addr];
	};

	## Failed connection attempts are tracked until not seen for this interval.
	## A higher interval will detect slower scanners, but may also yield more
	## false positives.
	const scan_timeout = 15min &redef;

	## The threshold of the number of darknet hosts a scanning host has to have
	## scanned in order for the scan to be considered a darknet scan
	const dark_host_threshold = 3 &redef;

	## The threshold of the unique number of host+ports a remote scanning host
	## has to have failed connections with
	const scan_threshold = 25 &redef;

	## The threshold of the unique number of host+ports a local scanning host
	## has to have failed connections with
	## local_scan_threshold の設定値とテスト方法のまとめ
    ##
    ## 元々のデフォルト値は '250' でしたが、テスト環境（アクティブホスト9台）では
    ## 検知が難しいため、テスト内容に応じて値を変更します。
    ##
    ## --------------------------------------------------------------------------
    ## 1. [SCAN PORT] および [SCAN ADDRESS] のテスト
    ## --------------------------------------------------------------------------
    ## const local_scan_threshold = 5 &redef;
    ##
    ## 閾値を '5' に設定。
    ##
    ## [SCAN PORT] 発火コマンド:
    ## nmap -sS -p- 172.30.0.20
    ## 理由: 1台のホストに約65,000回試行するため、閾値(5)を余裕で超える。
    ##       |victims|=1, |ports|>5 のため [PORT] に分類される。
    ##
    ## [SCAN ADDRESS] 発火コマンド:
    ## nmap -sS -p 80 -Pn 172.30.0.0/24
    ## 理由: 8台のアクティブホストに1ポートで試行 (試行回数 8回)。
    ##       閾値(5)を超え、|ports|=1 のため [ADDRESS] に分類される。
    ##
    ## --------------------------------------------------------------------------
    ## 2. [SCAN RANDOM] のテスト
    ## --------------------------------------------------------------------------
    ## const local_scan_threshold = 45 &redef;
    ##
    ## 閾値を '45' に設定。
    ##
    ## [SCAN RANDOM] 発火コマンド:
    ## nmap -sS -p 80,443,22,21,25,110 -Pn 172.30.0.0/24 (6ポート指定)
    ##
    ## 理由:
    ## 1. attacker自身(172.30.0.10)へのスキャンはZeekで観測されない。
    ## 2. 観測可能な試行回数は「8ホスト × 6ポート = 48回」となる。
    ## 3. 閾値を '45' に設定すると、nmapが5ポート分のスキャン (8*5=40回) を
    ##    終えた後、6ポート目のスキャン (41〜48回目) の途中で検知が発火する。
    ## 4. これにより、Zeekは |victims|=8, |ports|=6 のデータを分析でき、
    ##    |victims|>5 かつ |ports|>5 を満たすため [RANDOM] に分類される。
    ##
    ## (もし閾値が '5' のままだと、ポート80のスキャン中 (試行5回目) に
    ##  [SCAN ADDRESS] として早期検知されてしまうため、意図的に閾値を上げる)
    ## --------------------------------------------------------------------------
	const local_scan_threshold = 5 &redef;

	## The threshold of the unique number of host+ports a remote scanning host
	## has to have failed connections with if it has passed dark_host_threshold
	const scan_threshold_with_darknet_hits = 10 &redef;

	## The threshold of the unique number of host+ports a local scanning host
	## has to have failed connections with if it has passed dark_host_threshold
	const local_scan_threshold_with_darknet_hits = 100 &redef;

	## The threshold of the number of unique hosts a remote scanning host has
	## to have failed connections with
	const knockknock_threshold = 20 &redef;

	## The threshold of the number of unique hosts a remote scanning host has
	## to have failed connections with if it has passed dark_host_threshold
	const knockknock_threshold_with_darknet_hits = 3 &redef;

	## Override this hook to ignore particular scan connections
	global Scan::scan_policy: hook(scanner: addr, victim: addr, scanned_port: port);

	global scan_attempt: event(scanner: addr, attempt: Attempt);
	global attacks: table[addr] of Scan_Info &read_expire=scan_timeout &redef;
	global recent_scan_attempts: table[addr] of set[Attempt] &create_expire=1mins;

	global adjust_known_scanner_expiration: function(s: table[addr] of interval, idx: addr): interval;
	global known_scanners: table[addr] of interval &create_expire=10secs &expire_func=adjust_known_scanner_expiration;
}

event Notice::begin_suppression(ts: time, suppress_for: interval, note: Notice::Type, identifier: string)
{
	if ( note == Address_Scan || note == Random_Scan || note == Port_Scan )
	{
		local src = to_addr(identifier);
		known_scanners[src] = suppress_for;
		delete recent_scan_attempts[src];
	}
}

function adjust_known_scanner_expiration(s: table[addr] of interval, idx: addr): interval
{
	local duration = s[idx];
	s[idx] = 0secs;
	return duration;
}

@if ( !Cluster::is_enabled() || Cluster::local_node_type() != Cluster::WORKER )
function analyze_unique_hostports(attempts: set[Attempt]): Notice::Info
{
	local ports: set[port];
	local victims: set[addr];

	local ports_str: set[string];
	local victims_str: set[string];

	for ( a in attempts )
	{
		add victims[a$victim];
		add ports[a$scanned_port];

		add victims_str[cat(a$victim)];
		add ports_str[cat(a$scanned_port)];
	}
	
	if ( |ports| == 1 )
	{
		for ( p in ports )
			return [$note=Address_Scan, $msg=fmt("%s unique hosts on port %s", |victims|, p), $p=p];
	}

	if ( |victims| == 1 )
	{
		for ( v in victims )
			return [$note=Port_Scan, $msg=fmt("%s unique ports on host %s", |ports|, v)];
	}

	if ( |ports| <= 5 )
	{
		local ports_string = join_string_set(ports_str, ", ");
		return [$note=Address_Scan, $msg=fmt("%s unique hosts on ports %s", |victims|, ports_string)];
	}

	if ( |victims| <= 5 )
	{
		local victims_string = join_string_set(victims_str, ", ");
		return [$note=Port_Scan, $msg=fmt("%s unique ports on hosts %s", |ports|, victims_string)];
	}

	return [$note=Random_Scan, $msg=fmt("%d hosts on %d ports", |victims|, |ports|)];
}

function generate_notice(scanner: addr, si: Scan_Info): Notice::Info
{
	local side = Site::is_local_addr(scanner) ? "local" : "remote";
	local dur = duration_to_mins_secs(network_time() - si$first_seen);
	local n = analyze_unique_hostports(si$attempts);
	n$msg = fmt("%s scanned at least %s in %s", scanner, n$msg, dur);
	n$src = scanner;
	n$sub = side;
	n$identifier = cat(scanner);
	return n;
}

function add_scan_attempt(scanner: addr, attempt: Attempt)
{
	if ( scanner in known_scanners )
		return;

	local si: Scan_Info;
	local attempts: set[Attempt];
	local dark_hosts: set[addr];
	local port_counts: table[port] of count;

	if ( scanner !in attacks )
	{
		attempts = set();
		port_counts = table();
		dark_hosts = set();
		si = Scan_Info($first_seen=network_time(), $attempts=attempts, $port_counts=port_counts, $dark_hosts=dark_hosts);
		attacks[scanner] = si;
	}
	else
	{
		si = attacks[scanner];
		attempts = si$attempts;
		port_counts = si$port_counts;
		dark_hosts = si$dark_hosts;
	}
	
	if ( attempt in attempts )
		return;

	add attempts[attempt];

	if ( attempt$scanned_port !in port_counts )
		port_counts[attempt$scanned_port] = 1;
	else
		++port_counts[attempt$scanned_port];

	local thresh: count;
	local is_local = Site::is_local_addr(scanner);

	local is_darknet_scan = |dark_hosts| >= dark_host_threshold;

	if ( is_darknet_scan )
		thresh = is_local ? local_scan_threshold_with_darknet_hits : scan_threshold_with_darknet_hits;
	else
		thresh = is_local ? local_scan_threshold : scan_threshold;

	local is_scan = |attempts| >= thresh;
	local is_knockkock = F;

	if ( !is_local )
	{
		local knock_thresh = is_darknet_scan ? knockknock_threshold_with_darknet_hits : knockknock_threshold;
		is_knockkock = port_counts[attempt$scanned_port] >= knock_thresh;
	}

	if ( is_scan || is_knockkock )
	{
		local note = generate_notice(scanner, si);
		if ( is_knockkock )
			note$msg = fmt("kk: %s", note$msg);

        # ★ タグ付きリアルタイム出力
		local tag = "";

		if ( note$note == Address_Scan )
			tag = "[SCAN ADDRESS]";     # 多数ホストに同一ポートでスキャン
		else if ( note$note == Port_Scan )
			tag = "[SCAN PORT]";        # 1ホストに多数ポート
		else if ( note$note == Random_Scan )
			tag = "[SCAN RANDOM]";      # 複数ホスト・複数ポート
		else
			tag = "[SCAN]";

		print fmt("%s ts=%.6f scanner=%s side=%s msg=\"%s\"",
		    tag,
		    network_time(),
		    scanner,
		    note$sub,
		    note$msg
		);
		NOTICE(note);
		delete attacks[scanner];
		known_scanners[scanner] = 1hrs;
	}
}
@endif

@if ( Cluster::is_enabled() )
######################################
# Cluster mode
@ifdef (Cluster::worker2manager_events)
	redef Cluster::worker2manager_events += /Scan::scan_attempt/;
@endif

function add_scan(id: conn_id)
{
	local scanner      = id$orig_h;
	local victim       = id$resp_h;
	local scanned_port = id$resp_p;

	if ( scanner in known_scanners )
		return;

	if ( hook Scan::scan_policy(scanner, victim, scanned_port) )
	{
		local attempt = Attempt($victim=victim, $scanned_port=scanned_port);
		if ( scanner !in recent_scan_attempts )
			recent_scan_attempts[scanner] = set();
		if ( attempt in recent_scan_attempts[scanner] )
			return;
		add recent_scan_attempts[scanner][attempt];

@ifdef (Cluster::worker2manager_events)
		event Scan::scan_attempt(scanner, attempt);
@else
		Cluster::publish_hrw(Cluster::proxy_pool, scanner, Scan::scan_attempt, scanner, attempt);
@endif

		local thresh = Site::is_local_addr(scanner) ? local_scan_threshold : scan_threshold;
		if ( |recent_scan_attempts[scanner]| >= thresh )
		{
			known_scanners[scanner] = 1hrs;
			delete recent_scan_attempts[scanner];
		}
	}
}

@if ( Cluster::local_node_type() != Cluster::WORKER )
event Scan::scan_attempt(scanner: addr, attempt: Attempt)
{
	add_scan_attempt(scanner, attempt);
}
@endif
######################################

@else
######################################
# Standalone mode
function add_scan(id: conn_id)
{
	local scanner      = id$orig_h;
	local victim       = id$resp_h;
	local scanned_port = id$resp_p;

	if ( hook Scan::scan_policy(scanner, victim, scanned_port) )
	{
		add_scan_attempt(scanner, Attempt($victim=victim, $scanned_port=scanned_port));
	}
}
@endif
######################################

event connection_attempt(c: connection)
{
	if ( c$history == "S" || c$history == "SW" )
		add_scan(c$id);
}

event connection_rejected(c: connection)
{
	if ( c$history == "Sr" || c$history == "SWr" )
		add_scan(c$id);
}

#event connection_reset(c: connection)
#{
#	if ( c$history == "ShR" )
#		add_scan(c$id);
#}
