#!/bin/bash
SH_PATH=$(cd "$(dirname "$0")";pwd)
cd ${SH_PATH}

create_mainfest_file(){
    echo "进行配置。。。"
    read -p "请输入你的应用名称：" IBM_APP_NAME
    echo "应用名称：${IBM_APP_NAME}"
	read -p "请输入你的运行环境：" IBM_APP_NUM
    echo "运行环境：${IBM_APP_NUM}"
	read -p "请输入V2伪装文件名称：" IBM_V2_NAME
    echo "伪装名称：${IBM_V2_NAME}"
	echo "生成随机UUID：${UUID}"
    WSPATH=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    echo "生成随机WebSocket路径：${WSPATH}"
    read -p "请输入你的应用内存大小(默认256)：" IBM_MEM_SIZE
    if [ -z "${IBM_MEM_SIZE}" ];then
    IBM_MEM_SIZE=256
    fi
    echo "内存大小：${IBM_MEM_SIZE}"
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "生成随机UUID：${UUID}"
    
    
    cat >  ${SH_PATH}/IBMAllYes/w2r/${IBM_APP_NUM}/manifest.yml  << EOF
    applications:
    - path: .
      name: ${IBM_APP_NAME}
      random-route: true
      memory: ${IBM_MEM_SIZE}M
EOF
	cat >  ${SH_PATH}/IBMAllYes/w2r/${IBM_APP_NUM}/Procfile  << EOF
    web: ./${IBM_V2_NAME}/${IBM_V2_NAME}

EOF

    cat >  ${SH_PATH}/IBMAllYes/cherbim/v2ray/config.json  << EOF
    {
        "inbounds": [
            {
                "port": 8080,
                "protocol": "vmess",
                "settings": {
                    "clients": [
                        {
                            "id": "${UUID}",
                            "alterId": 4
                        }
                    ]
                },
                "streamSettings": {
                    "network":"ws",
                    "wsSettings": {
                        "path": "${WSPATH}"
                    }
                }
            }
        ],
        "outbounds": [
            {
                "protocol": "freedom",
                "settings": {}
            }
        ]
    }
EOF
    echo "配置完成。"
}

clone_repo(){
    echo "进行初始化。。。"
	rm -rf IBMAllYes
    git clone https://github.com/w2r/IBMAllYes.git
    cd IBMAllYes
    git submodule update --init --recursive
    cd cherbim/v2ray
    # Upgrade V2Ray to the latest version
    rm v2ray v2ctl
    
    # Script from https://github.com/v2fly/fhs-install-v2ray/blob/master/install-release.sh
    # Get V2Ray release version number
    TMP_FILE="$(mktemp)"
    if ! curl -s -o "$TMP_FILE" 'https://api.github.com/repos/v2fly/v2ray-core/releases/latest'; then
        rm "$TMP_FILE"
        echo 'error: 获取最新V2Ray版本号失败。请重试'
        exit 1
    fi
    RELEASE_LATEST="$(sed 'y/,/\n/' "$TMP_FILE" | grep 'tag_name' | awk -F '"' '{print $4}')"
    rm "$TMP_FILE"
    echo "当前最新V2Ray版本为$RELEASE_LATEST"
    # Download latest release
    DOWNLOAD_LINK="https://github.com/v2fly/v2ray-core/releases/download/$RELEASE_LATEST/v2ray-linux-64.zip"
    if ! curl -L -H 'Cache-Control: no-cache' -o "latest-v2ray.zip" "$DOWNLOAD_LINK"; then
        echo 'error: 下载V2Ray失败，请重试'
        return 1
    fi
    unzip latest-v2ray.zip v2ray v2ctl geoip.dat geosite.dat
    rm latest-v2ray.zip
    
    chmod 0755 ./*
    cd ${SH_PATH}/IBMAllYes/w2r/${IBM_APP_NUM}
    echo "初始化完成。"
}

install(){
    echo "进行安装。。。"
    cd ${SH_PATH}/IBMAllYes/w2r/${IBM_APP_NUM}
	# 把v2ray伪装成其他文件夹（比如cherbim，请自行命名，最好全英文）
	mv ${SH_PATH}/IBMAllYes/cherbim/v2ray ${SH_PATH}/IBMAllYes/w2r/${IBM_APP_NUM}/${IBM_V2_NAME}
	mv ${SH_PATH}/IBMAllYes/w2r/${IBM_APP_NUM}/${IBM_V2_NAME}/v2ray ${SH_PATH}/IBMAllYes/w2r/${IBM_APP_NUM}/${IBM_V2_NAME}/${IBM_V2_NAME}
	# 把代码push到容器
    ibmcloud target --cf
    echo "N"|ibmcloud cf install
    ibmcloud cf push
    echo "安装完成。"
    echo "生成的随机 UUID：${UUID}"
	
    VMESSCODE=$(base64 -w 0 << EOF
    {
      "v": "2",
      "ps": "ibmyes",
      "add": "*****.us-south.cf.appdomain.cloud",
      "port": "443",
      "id": "${UUID}",
      "aid": "4",
      "net": "ws",
      "type": "none",
      "host": "",
      "path": "${WSPATH}",
      "tls": "tls"
    }
EOF
    )
	# 输出vmess链接
	echo "配置链接："
    echo vmess://${VMESSCODE}

}

clone_repo
create_mainfest_file
install
exit 0