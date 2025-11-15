# victim コンテナ（Ubuntu Server）
本コンテナは、攻撃者（attacker）からの攻撃を受ける **被害者サーバ** として動作します。  
HTTPサーバやSSHサーバを起動して、DoS攻撃・Slow HTTP攻撃・ブルートフォース攻撃の  
挙動を安全な閉域ネットワーク内で観察するために利用します。

内部ネットワーク `testnet_static` にのみ接続されており、  
外部ネットワークに露出することはありません。

---

## 📦 インストールされている主要パッケージ

### 🔹 ネットワーク基本ツール
- `iproute2`
- `iputils-ping`
- `net-tools`
- `tcpdump`

### 🔹 サーバ関連
- `python3`  
  → `python3 -m http.server` による簡易 HTTP サーバ  
- `openssh-server`  
  → SSH サーバ（解析・ブルートフォース実験用）

### 🔹 テキストエディタ
- vim  
- nano

---

## 🐳 コンテナ設定情報

### Dockerfile
```Dockerfile
FROM ubuntu:latest

RUN apt update && \
    apt install -y \
      iproute2 \
      iputils-ping \
      net-tools \
      tcpdump \
      python3 \
      openssh-server \
      vim \
      nano \
      && apt clean && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリ
WORKDIR /workspace
```

### docker-compose 設定

```yaml
 victim:
    build: ./victim
    container_name: victim
    command: tail -f /dev/null
    cap_add:
      - NET_RAW
      - NET_ADMIN
    networks:
      testnet_static:
        ipv4_address: 172.30.0.20
    volumes:
      - ./victim/data:/workspace
```

---

## ▶️ コンテナへのアクセス
```bash
docker exec -it victim bash
```

---

## 📁 `/workspace` ディレクトリについて
* ホストの `./victim/data/` と同期されています
* HTML / test scripts / pcap など実験用データの保管場所として利用できます

例：
```pgsql
./victim/data/
└── server/
    ├── index.html
    └── test.json
```

---

## 🧪 使用例

### ▼ 1. HTTP サーバを起動する（8080番）
```bash
python3 -m http.server 8080 
```
**🔹 バックグラウンドで起動させたい場合**

末尾に & を付けることで、HTTP サーバをバックグラウンド実行できます。
```bash
python3 -m http.server 8080 &
```
**🔹 サーバを停止したい場合**

バックグラウンドで起動したプロセスは **手動で kill する必要があります。**

まずプロセスID（PID）を確認：
```bash
ps aux | grep http.server
```
出てきた PID を指定して停止：
```bash
kill <PID>
```

### ▼ 2. SSH サーバを起動する（8080番）
```bash
service ssh start
```
**🔹 サーバを停止したい場合**
```bash
service ssh stop
```

### ▼ 3. tcpdump によるパケット収集
```bash
tcpdump -i eth0 -w /workspace/capture.pcap
```
これによりZeek や Wireshark で後から解析可能になります。

---

## 🔒 注意事項
* victim は攻撃を受けるために設計されたコンテナです。
攻撃ツールをインストールしないことを推奨します。

* デフォルトでは root パスワードが設定されていないため、
SSH 認証の実験を行う場合はパスワードを適宜設定してください。

* 外部ネットワークには露出しないよう、
testnet_static 以外に接続しないようにしてください。

---

## 📝 補足：victim でよく使う Linux コマンド
| コマンド              | 用途                                |
| ----------------- | --------------------------------- |
| `ss -lnt`            | リッスン中の TCP ポート確認                       |
| `ps aux`         | プロセス一覧 |
| `tcpdump -i eth0` | ライブパケット観測                      |

---

## 📌 バージョン情報
* Base image: `ubuntu:latest`

* Tools: tcpdump / ping / vim / nano など


* Services: Python HTTP Server / OpenSSH Server


