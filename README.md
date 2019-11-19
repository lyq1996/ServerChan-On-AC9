# ServerChan-On-AC9
在运行Asuswrt的AC9上通过「Server酱」推送DDNS更新消息和上下线设备。

# 自启动
1. 原版Asuswrt如果使用optware，可以在挂载usb后实现自启动，参见[Entware-ng](https://github.com/Entware/Entware/wiki/Install-on-Asus-stock-firmware)。

2. 移植了部分Merlin功能的Asuswrt，利用User Scripts可实现部分自启动，参见[User scripts](https://github.com/RMerl/asuswrt-merlin/wiki/User-scripts)

# DDNS
Cloud Flare的ddns，填上APi token等参数就行了
```
APITOKEN=""     # Your API Token
ZONEID=""       # Your zone id, hex16 string
RECORDNAME=""   # Your DNS record name, e.g. sub.example.com
RECORDTTL="1"   # TTL in seconds (1=auto)
```

# ServerChan
```
push1="1"               # Push online devices
push_ddns="1"           # Push ddns message
serverchan_enable="1"   # Enable ServerChan
serverchan_sckey=""     # ServerChan api key
```

# 致谢
1. 这里的推送上下线设备和server酱推送用的是Hiboy的代码  
2. 检测上下线参考了[Asuswrt-Merlin-Linux-Shell-Scripts](https://github.com/Xentrk/Asuswrt-Merlin-Linux-Shell-Scripts/blob/master/profile.add#L18)
