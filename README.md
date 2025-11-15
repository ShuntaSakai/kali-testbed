# kali-testbed  
閉域ネットワーク上で攻撃実験・パケット解析を行うための Docker ベース実験環境

本環境は、**攻撃者（Kali）・被害者（Ubuntu）・監視者（Zeek）** の 3 コンテナを  
同一の隔離ネットワーク上に構築し、DoS 攻撃や Slow HTTP 攻撃の挙動を  
安全に解析することを目的としたテストベッドです。

※ すべて **自分の管理下のマシン内でのみ** 使用すること。外部ネットワークへの攻撃は禁止。

---

## 📁 ディレクトリ構成
```
kali-testbed/
├── attacker/
│ ├── Dockerfile
│ └── data/
│
├── victim/
│ ├── Dockerfile
│ └── data/
│
├── zeek/
│ ├── Dockerfile
│ ├── logs/
│ └── scripts/
│
└── docker-compose.yml
```


---

## 🧩 各ディレクトリの役割

### **attacker/**
攻撃者用（Kali Linux ベース）コンテナ。

- 攻撃ツールを利用する側  
  - `hping3`（SYN Flood）  
  - `slowhttptest`（Slowloris / Slow Headers）  
  - `patator`（Brute force）  
  - `nmap`（スキャン）  
- `data/` はログや pcap を保存したいときのワークスペース  
- Dockerfile でパッケージをインストールして構築

---

### **victim/**
被害者用（Ubuntu ベース）コンテナ。

- 攻撃対象サーバとして動作  
  - `python3 -m http.server` による簡易 HTTP サーバ  
  - `openssh-server` による SSH サービス  
- 攻撃の受信挙動を観測する目的で構築  
- `data/` は実験用ファイル置き場

---

### **zeek/**
ネットワークモニタリング（IDS / NIDS）として動作。

- `Dockerfile`：Zeek ベースイメージを拡張（必要パッケージの追加など）
- `scripts/`：Zeek スクリプト（例：syn-flood、bruteforce 検知）
- `logs/`：Zeek のログ出力先。  
  `zeek -r <pcap>` やライブ解析の結果がここに保存される。

Zeek を使うことで、攻撃の挙動を L7/TCP/IP のレベルで解析可能。

---

## 🌐 Docker ネットワーク構成

`docker-compose.yml` では、**内部ネットワーク（--internal）** である  
`testnet_static` を定義し、次のような通信が可能です。

| コンテナ | IPアドレス | 説明 |
|----------|-----------|------|
| attacker | 172.30.0.10 | 攻撃者 |
| victim   | 172.30.0.20 | 被害者 |

`internal: true` のため外部インターネットへは出られず、  
閉域環境内で安全に攻撃挙動の実験ができる。

---

## 🚀 起動方法

### 1. コンテナのビルド & 起動
```bash
docker compose up --build -d
```

### 2. 各コンテナへのアクセス
```bash
docker exec -it attacker bash
docker exec -it victim bash
docker exec -it zeek bash
```

---

## 🧪 基本的な使い方（例）

### ▼ victim で HTTP サーバ起動
```bash
python3 -m http.server 8080
```

### ▼ attacker から正常アクセス（正常系キャプチャ）
```bash
curl http://172.30.0.20:8080/
```

### ▼ attacker から Slowloris 攻撃
```bash
slowhttptest -c 20 -H -g -i 10 -r 20 -t GET -u http://172.30.0.20:8080/ -x 24 -s 30
```

### ▼ zeek で pcap を解析
```bash
zeek -r capture.pcap zeek-scripts/
```


---

## 🔒 注意事項

- 外部ネットワークに向けた攻撃は **絶対に実行しないこと**
- この環境は **完全な閉域**（Docker の internal network）で動作する
- 学習目的であり、実運用環境への適用は推奨しない

