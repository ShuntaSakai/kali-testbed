# zeek コンテナ（Network Monitoring / IDS）
本コンテナは、攻撃者（attacker）と被害者（victim）間の通信を監視する  
**ネットワーク監視・解析コンテナ（Zeek / Bro）** として動作します。  

Zeek を用いて、DoS 攻撃・SYN Flood・Slow HTTP 攻撃などの挙動を  
TCP/IP・L7レベルで詳細に解析することを目的としています。

内部ネットワーク `testnet_static` 内のみで動作し、  
外部に露出することはありません。

---

## 📦 インストールされている主要パッケージ

### 🔹 Zeek（メインの NIDS ツール）
- 既存の Zeek イメージ `zeek/zeek:latest` を使用
- コンテナ内で `zeek` コマンドにより pcap 解析やライブ解析が可能

### 🔹 ネットワーク基本ツール
- `iproute2`
- `iputils-ping`
- `net-tools`
- `tcpdump`（パケットキャプチャ）

### 🔹 テキストエディタ
- vim  
- nano  
- less

---

## 🐳 コンテナ設定情報

### Dockerfile

```Dockerfile
FROM zeek/zeek:latest

RUN apt update && \
    apt install -y \
      iproute2 \
      iputils-ping \
      net-tools \
      tcpdump \
      less \
      nano \
      vim \
      && apt clean && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /zeek-logs /zeek-scripts
```

### docker-compose 設定
```yaml
  zeek:
    build: ./zeek
    container_name: zeek
    command: tail -f /dev/null
    cap_add:
      - NET_RAW
      - NET_ADMIN
    networks:
      testnet_static:
    volumes:
      - ./zeek/logs:/zeek-logs
      - ./zeek/scripts:/zeek-scripts
      - ./bin/zeek-color:/usr/local/bin/zeek-color
```

---

## ▶️ コンテナへのアクセス
```bash
docker exec -it zeek bash
```

---

## 📁 ディレクトリ構成について
### `/zeek-scripts`
ホストの `./zeek/scripts/` と同期されています。
カスタム Zeek スクリプト（`.zeek` ファイル）を置く場所です。

例：
```pgsql
./zeek/scripts/
├── syn-flood.zeek
└── http-monitor.zeek
```

### `/zeek-logs`
ホストの `./zeek/logs/` と同期されています。
Zeek が出力するログファイルを保存するディレクトリです。

例：
```pgsql
./zeek/logs/
├── conn.log
├── http.log
├── notice.log
└── weird.log
```

### `/usr/local/bin/zeek-color`
Zeek ログのカラー表示ツールをホスト側から提供

---

## 🧪 使用例
### リアルタイム監視用スクリプト
```bash
zeek-color -i [`ip a`で調べた、attacker と victim が接続されているDockerブリッジのインターフェース名] \
  /zeek-scripts/thirdparty/syn-flood \
  /zeek-scripts/thirdparty/bro-simple-scan/scripts
```

---

## 🔒 注意事項
* Zeek は大量のログを生成するため、
不要な解析は行わず適宜 `logs/` を整理してください。

* 外部ネットワークには接続していないため、
Zeek の解析はすべて `testnet_static` 内に限定されます。

---

## 📝 補足：zeek でよく使うコマンドまとめ
| コマンド              | 用途                                |
| ----------------- | --------------------------------- |
| `zeek -r file.pcap`            | pcap のオフライン解析                |
| `zeek -r file.pcap script.zeek`         | カスタムスクリプト適用 |
| `less conn.log` | 通信ログの確認                     |
| `ip a`          | ネットワークインターフェース（NIC）と、それに割り当てられたIPアドレスなどの情報を一覧表示 | 
---

## 📌 バージョン情報
* Base image: `zeek/zeek:latest`

* Tools: tcpdump / ping / vim / nano など


