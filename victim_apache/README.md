# victim_apache コンテナ（Ubuntu + Apache2）
本コンテナは、攻撃者（attacker）からの攻撃対象となる Apache Web サーバ を提供します。
Slowloris（Slow HTTP）、DoS、HTTP Flood などの攻撃挙動を安全な閉域ネットワーク内で観察するために利用します。

内部ネットワーク `testnet_static` のみへ接続されており、
外部に露出することはありません。

---

## 📦 インストールされている主要パッケージ

### 🔹 ネットワーク基本ツール
- `iproute2`
- `iputils-ping`
- `net-tools`
- `tcpdump`

### 🔹 Web サーバ（メイン）
- `Apache2（mpm_event）`  
  - 本コンテナ起動時に自動で開始
  - `apache2ctl -D FOREGROUND` でフォアグラウンド起動

### 🔹 テキストエディタ
- vim  
- nano

---

## 🐳 コンテナ設定情報

### Dockerfile
```Dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -y \
      apache2 \
      iproute2 \
      iputils-ping \
      net-tools \
      tcpdump \
      less \
      vim \
      nano \
      && apt clean && rm -rf /var/lib/apt/lists/*

RUN echo "ServerName victim_apache" >> /etc/apache2/apache2.conf

RUN a2enmod reqtimeout

# HTTP ポート
EXPOSE 80

# コンテナ起動と同時に Apache をフォアグラウンド起動
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]

WORKDIR /workspace
```

### docker-compose 設定

```yaml
  victim_apache:
    build: ./victim_apache
    container_name: victim_apache
    cap_add:
      - NET_RAW
      - NET_ADMIN
    networks:
      testnet_static:
        ipv4_address: 172.30.0.27
    ports:
      - "8080:80"
    volumes:
      - ./victim_apache/data:/workspace
```

---

## ▶️ コンテナへのアクセス
```bash
docker exec -it victim_apache bash
```

---

## 📁 `/workspace` ディレクトリについて
* ホストの `./victim_apache/data/` と同期されています
* Apache のログ保存、HTML 配置、テストスクリプトなどに使用可能

例：
```pgsql
./victim_apache/data/
└── html/
    ├── index.html
    └── test.json
```

---

## 🧪 使用例

### ▼ 1. Apache の状態確認
**Apache が起動しているか**
```bash
ps aux | grep apache2
```
**ポート 80 が LISTEN しているか**
```bash
ss -lntp | grep :80
```

### ▼ 2. Apache の再起動方法（⚠ systemctl は使えません）
```bash
apache2ctl restart
```

### ▼ 3. Apache のスレッド数（MPM event）の変更方法
**設定ファイルの場所**
```bash
/etc/apache2/mods-available/mpm_event.conf
```
編集：
```bash
nano /etc/apache2/mods-available/mpm_event.conf
```
**設定項目（例）**
```apache
<IfModule mpm_event_module>
    StartServers             2
    MinSpareThreads         25
    MaxSpareThreads         75
    ThreadLimit             64
    ThreadsPerChild         25
    MaxRequestWorkers      150
    MaxConnectionsPerChild   0
</IfModule>
```
重要パラメータ：

| パラメータ                 | 説明                                       |
| --------------------- | ---------------------------------------- |
| **ThreadsPerChild**   | 子プロセスごとのスレッド数                            |
| **MaxRequestWorkers** | 同時処理できる最大スレッド数（ThreadsPerChild × 子プロセス数） |
| **ThreadLimit**       | ThreadsPerChild の上限値                     |


スレッド数変更後は、サーバの再起動（▼ 2. Apache の再起動方法）を行う

### ▼ 4. Apache のログ確認
**アクセスログ**
```pgsql
/var/log/apache2/access.log
```
**エラーログ**
```lua
/var/log/apache2/error.log
```

### ▼ 5. tcpdump によるトラフィック収集
```bash
tcpdump -i eth0 -w /workspace/capture.pcap
```
Zeek や Wireshark で解析可能。

---

## 🔒 注意事項
* victim_apache は攻撃を受けるために設計されたコンテナです。
攻撃ツールをインストールしないことを推奨します。

* Apache の設定を緩めすぎるとコンテナがフリーズする可能性があります。
設定実験を行う際は注意してください。

* 外部ネットワークには露出しないよう、
testnet_static 以外に接続しないようにしてください。

---

## 📝 補足：よく使う Linux / Apache コマンド
| コマンド                                 | 用途                  |
| ------------------------------------ | ------------------- |
| `ss -lnt`                            | LISTEN 中の TCP ポート確認 |
| `ps aux`                             | プロセス確認              |
| `apache2ctl restart`                 | Apache の再起動         |
| `apache2ctl configtest`              | 設定ファイルの構文チェック       |
| `grep -R`                            | 設定の検索               |
| `tail -f /var/log/apache2/error.log` | エラーログ監視             |


---

## 📌 バージョン情報
* Base image: `ubuntu:22.04`

* Tools: tcpdump / ping / vim / nano など

* Apache MPM: event


