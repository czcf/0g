#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 检查并安装 Node.js 和 npm
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo "Node.js 已安装"
    else
        echo "Node.js 未安装，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if command -v npm > /dev/null 2>&1; then
        echo "npm 已安装"
    else
        echo "npm 未安装，正在安装..."
        sudo apt-get install -y npm
    fi
}

# 检查并安装 PM2
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo "PM2 已安装"
    else
        echo "PM2 未安装，正在安装..."
        npm install pm2@latest -g
    fi
}

# 检查Go环境
function check_go_installation() {
    if command -v go > /dev/null 2>&1; then
        echo "Go 环境已安装"
        return 0
    else
        echo "Go 环境未安装，正在安装..."
        return 1
    fi
}

# 节点安装功能
function install_node() {

    install_nodejs_and_npm
    install_pm2

    # 检查curl是否安装，如果没有则安装
    if ! command -v curl > /dev/null; then
        sudo apt update && sudo apt install curl git -y
    fi

    # 更新和安装必要的软件
    sudo apt update && sudo apt upgrade -y
    sudo apt install git wget build-essential jq make lz4 gcc liblz4-tool -y

    # 安装 Go
    if ! check_go_installation; then
        sudo rm -rf /usr/local/go
        curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
        source $HOME/.bash_profile
        go version
    fi

    # 安装所有二进制文件
    git clone -b v0.3.1 https://github.com/0glabs/0g-chain.git
    cd 0g-chain
    make install
    source ~/.profile

    # 配置0gchaind
    export MONIKER="My_Node"
    export WALLET_NAME="wallet"

    # 初始化节点
    cd $HOME
    0gchaind init $MONIKER --chain-id zgtendermint_16600-2
    0gchaind config chain-id zgtendermint_16600-2
    0gchaind config node tcp://localhost:13457

    # 配置创世文件
    rm ~/.0gchain/config/genesis.json
    wget -P ~/.0gchain/config https://public-snapshot-storage-develop.s3.ap-southeast-1.amazonaws.com/zerog/zgtendermint_16600-2/genesis.json
    0gchaind validate-genesis

    # 配置节点
    SEEDS="8f21742ea5487da6e0697ba7d7b36961d3599567@og-testnet-seed.itrocket.net:47656"
    PEERS="80fa309afab4a35323018ac70a40a446d3ae9caf@og-testnet-peer.itrocket.net:11656,9dbb76298d1625ebcc47d08fa7e7911967b63b61@45.159.221.57:26656,a2caf26a86a4989e26943e496173e7b22831c88a@198.7.116.141:12656,0ae19691f97f5797694c253bc06c79c8b58ea2a8@85.190.242.81:26656,c0d35052a7612d992f721b25f186a5d1f569405e@195.201.194.188:26656,8bd2797c8ece0f099a1c31f98e5648d192d8cd54@38.242.146.162:26656,c85eaa1b3cbe4d7fb19138e5a5dc4111491e6e03@115.78.229.59:10156,fa08f548e8d34b6c72ed9e7495a59ae6be656da8@109.199.97.178:12656,ffdf7a8cc6dbbd22e25b1590f61da149349bdc2e@135.181.229.206:26656,56ee4c337848a70a43887531b5f1ca211bac1a34@185.187.170.125:26656"
    sed -i "s/persistent_peers = \"\"/persistent_peers = \"$PEERS\"/" $HOME/.0gchain/config/config.toml
    sed -i "s/seeds = \"\"/seeds = \"$SEEDS\"/" $HOME/.0gchain/config/config.toml
    sed -i -e 's/max_num_inbound_peers = 40/max_num_inbound_peers = 100/' -e 's/max_num_outbound_peers = 10/max_num_outbound_peers = 100/' $HOME/.0gchain/config/config.toml
    wget -O $HOME/.0gchain/config/addrbook.json https://server-5.itrocket.net/testnet/og/addrbook.json


    # 配置裁剪
    sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.0gchain/config/app.toml
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.0gchain/config/app.toml
    sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"0\"/" $HOME/.0gchain/config/app.toml
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.0gchain/config/app.toml

    # 配置端口
    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:13458\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:13457\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:13460\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:13456\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":13466\"%" $HOME/.0gchain/config/config.toml
    sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:13417\"%; s%^address = \":8080\"%address = \":13480\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:13490\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:13491\"%; s%:8545%:13445%; s%:8546%:13446%; s%:6065%:13465%" $HOME/.0gchain/config/app.toml
    source $HOME/.bash_profile

    # 下载快照
    cp $HOME/.0gchain/data/priv_validator_state.json $HOME/.0gchain/priv_validator_state.json.backup
    rm -rf $HOME/.0gchain/data
    curl -L https://snapshots.dadunode.com/0gchain/0gchain_latest_tar.lz4 | tar -I lz4 -xf - -C $HOME/.0gchain/data
    mv $HOME/.0gchain/priv_validator_state.json.backup $HOME/.0gchain/data/priv_validator_state.json

    # 使用 PM2 启动节点进程
    pm2 start 0gchaind -- start --log_output_console --home ~/.0gchain && pm2 save && pm2 startup
    pm2 restart 0gchaind

    echo '====================== 安装完成,请退出脚本后执行 source $HOME/.bash_profile 以加载环境变量==========================='

}

# 查看 PM2 服务状态
function check_service_status() {
    pm2 list
}

# 验证节点日志查询
function view_logs() {
    pm2 logs 0gchaind
}

# 卸载节点功能
function uninstall_node() {
    echo "你确定要卸载0gchain 节点程序吗？这将会删除所有相关的数据。[Y/N]"
    read -r -p "请确认: " response

    case "$response" in
        [yY][eE][sS]|[yY])
            echo "开始卸载节点程序..."
            pm2 stop 0gchaind && pm2 delete 0gchaind
            rm -rf $HOME/.0gchain $HOME/0gchain $(which 0gchaind) && rm -rf 0g-chain
            echo "节点程序卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

# 创建钱包
function add_wallet() {
    read -p "请输入你想设置的钱包名称: " wallet_name
    0gchaind keys add $wallet_name --eth
}

# 导入钱包
function import_wallet() {
    read -p "请输入你想设置的钱包名称: " wallet_name
    0gchaind keys add $wallet_name --recover --eth
}

# 查询余额
function check_balances() {
    echo "请确认同步到最新区块之后再查询余额"
    read -p "请输入钱包地址: " wallet_address
    0gchaind query bank balances "$wallet_address"
}

# 查看节点同步状态
function check_sync_status() {
    0gchaind status | jq .sync_info
}

# 创建验证者
function add_validator() {

    read -p "请输入您的钱包名称: " wallet_name
    read -p "请输入您想设置的验证者的名字: " validator_name
    read -p "请输入您的验证者详情（例如'吊毛资本'）: " details


    0gchaind tx staking create-validator \
    --amount=1000000ua0gi \
    --pubkey=$(0gchaind tendermint show-validator) \
    --moniker=$validator_name \
    --chain-id=zgtendermint_16600-2 \
    --commission-rate=0.05 \
    --commission-max-rate=0.10 \
    --commission-max-change-rate=0.01 \
    --min-self-delegation=1 \
    --from=$wallet_name \
    --identity="" \
    --website="" \
    --details="$details" \
    --gas=auto \
    --gas-adjustment=1.4
}

function install_storage_node() {

    sudo apt-get update
    sudo apt-get install clang cmake build-essential git screen cargo -y


    # 安装 Go
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    source $HOME/.bash_profile


    # 克隆仓库
    git clone -b v0.4.2 https://github.com/0glabs/0g-storage-node.git

    # 进入对应目录构建
    cd 0g-storage-node
    git submodule update --init

    # 构建代码
    echo "准备构建，该步骤消耗一段时间。请保持 SSH 不要断开。看到 Finish 字样为构建完成。"
    cargo build --release

    # 编辑配置

    read -p "请输入你想导入的EVM钱包私钥，不要有0x: " miner_key
    read -p "请输入设备 IP 地址（本地机器请输入127.0.0.1）: " public_address
    read -p "请输入使用的 JSON-RPC : " json_rpc
    sed -i '
    s|# network_enr_address = ""|network_enr_address = "'$public_address'"|
    s|# blockchain_rpc_endpoint = ".*"|blockchain_rpc_endpoint = "'$json_rpc'"|
    s|# miner_key = ""|miner_key = "'$miner_key'"|
    ' $HOME/0g-storage-node/run/config-testnet-turbo.toml

    # 启动
    cd ~/0g-storage-node/run
    screen -dmS zgs_node_session $HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config-testnet-turbo.toml


    echo '====================== 安装完成，使用 screen -ls 命令查询即可 ==========================='

}


function install_storage_kv() {

    # 克隆仓库
    git clone https://github.com/0glabs/0g-storage-kv.git


    #进入对应目录构建
    cd 0g-storage-kv
    git submodule update --init

    # 构建代码
    cargo build --release

    #后台运行
    cd run

    echo "请输入RPC节点信息: "
    read blockchain_rpc_endpoint


cat > config.toml <<EOF
stream_ids = ["000000000000000000000000000000000000000000000000000000000000f2bd", "000000000000000000000000000000000000000000000000000000000000f009", "00000000000000000000000000"]

db_dir = "db"
kv_db_dir = "kv.DB"

rpc_enabled = true
rpc_listen_address = "127.0.0.1:6789"
zgs_node_urls = "http://127.0.0.1:5678"

log_config_file = "log_config"

blockchain_rpc_endpoint = "$blockchain_rpc_endpoint"
log_contract_address = "0x22C1CaF8cbb671F220789184fda68BfD7eaA2eE1"
log_sync_start_block_number = 670000

EOF

    echo "配置已成功写入 config.toml 文件"
    screen -dmS storage_kv ../target/release/zgs_kv --config config.toml

}

# 给自己地址验证者质押
function delegate_self_validator() {
    read -p "请输入质押代币数量(单位为ua0gai,比如你有1000000个ua0gai，留点水给自己，输入900000回车就行): " math
    read -p "请输入钱包名称: " wallet_name
    0gchaind tx staking delegate $(0gchaind keys show $wallet_name --bech val -a) ${math}ua0gi --from $wallet_name   --gas=auto --gas-adjustment=1.4 -y

}

# 查看存储节点日志
function check_storage_logs() {
    tail -f "$(find ~/0g-storage-node/run/log/ -type f -printf '%T+ %p\n' | sort -r | head -n 1 | cut -d' ' -f2-)"
}

# 过滤错误日志
function check_storage_error() {
    tail -f -n50 ~/0g-storage-node/run/log/zgs.log.$(TZ=UTC date +%Y-%m-%d) | grep ERROR
}

# 重启存储节点
function restart_storage() {
    # 退出现有进程
    screen -S zgs_node_session -X quit
    # 启动
    cd ~/0g-storage-node/run
    screen -dmS zgs_node_session $HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config-testnet-turbo.toml
    echo '====================== 启动成功，请通过screen -r zgs_node_session 查询 ==========================='

}

# 修改日志等级
function change_storage_log_level() {
    echo "DEBUG(1) > INFO(2) > WARN(3) > ERROR(4)"
    echo "DEBUG 等级日志文件最大，ERROR 等级日志文件最小"
    read -p "请选择日志等级(1-4): " level
    case "$level" in
        1)
            echo "debug,hyper=info,h2=info" > $HOME/0g-storage-node/run/log_config ;;
        2)
            echo "info,hyper=info,h2=info" > $HOME/0g-storage-node/run/log_config ;;
        3)
            echo "warn,hyper=info,h2=info" > $HOME/0g-storage-node/run/log_config ;;
        4)
            echo "error,hyper=info,h2=info" > $HOME/0g-storage-node/run/log_config ;;
    esac
    echo "修改完成，请重新启动存储节点"
}


# 统计日志文件大小
function storage_logs_disk_usage(){
    du -sh ~/0g-storage-node/run/log/
    du -sh ~/0g-storage-node/run/log/*
}


# 删除存储节点日志
function delete_storage_logs(){
    echo "确定删除存储节点日志？[Y/N]"
    read -r -p "请确认: " response
        case "$response" in
        [yY][eE][sS]|[yY])
            rm -r ~/0g-storage-node/run/log/*
            echo "删除完成，请重启存储节点"
            ;;
        *)
            echo "取消操作"
            ;;
    esac

}


# 转换 ETH 地址
function transfer_EIP() {
    read -p "请输入你的钱包名称: " wallet_name
    echo "0x$(0gchaind debug addr $(0gchaind keys show $wallet_name -a) | grep hex | awk '{print $3}')"

}


# 导出验证者key
function export_priv_validator_key() {
    echo "====================请将下方所有内容备份到自己的记事本或者excel表格中记录==========================================="
    cat ~/.0gchain/config/priv_validator_key.json

}

function uninstall_storage_node() {
    echo "你确定要卸载0g ai 存储节点程序吗？这将会删除所有相关的数据。[Y/N]"
    read -r -p "请确认: " response

    case "$response" in
        [yY][eE][sS]|[yY])
            echo "开始卸载节点程序..."
            rm -rf $HOME/0g-storage-node
            echo "节点程序卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

function update_script() {
    SCRIPT_PATH="./0g.sh"  # 定义脚本路径
    SCRIPT_URL="https://raw.githubusercontent.com/a3165458/0g.ai/main/0g.sh"

    # 备份原始脚本
    cp $SCRIPT_PATH "${SCRIPT_PATH}.bak"

    # 下载新脚本并检查是否成功
    if curl -o $SCRIPT_PATH $SCRIPT_URL; then
        chmod +x $SCRIPT_PATH
        echo "脚本已更新。请退出脚本后，执行bash 0g.sh 重新运行此脚本。"
    else
        echo "更新失败。正在恢复原始脚本。"
        mv "${SCRIPT_PATH}.bak" $SCRIPT_PATH
    fi

}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "脚本以及教程由推特用户大赌哥 @y95277777 编写，群友@rainy242869 维护更新,免费开源，请勿相信收费"
        echo "=======================0GAI节点安装================================"
        echo "=======================验证节点功能================================"
        echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
        echo "节点社区 Discord 社群:https://discord.gg/GbMV5EcNWF"
        echo "退出脚本，请按键盘ctrl c退出即可"
        echo "请选择要执行的操作:"
        echo "1. 安装节点"
        echo "2. 创建钱包"
        echo "3. 导入钱包"
        echo "4. 查看钱包地址余额"
        echo "5. 查看节点同步状态"
        echo "6. 查看当前服务状态"
        echo "7. 运行日志查询"
        echo "8. 卸载0gchain验证者节点"
        echo "9. 创建验证者"
        echo "10. 给自己验证者地址质押代币"
        echo "11. 转换ETH地址"
        echo "=======================存储节点功能================================"
        echo "12. 安装存储节点"
        echo "13. 查看存储节点日志"
        echo "14. 过滤错误日志"
        echo "15. 重启存储节点"
        echo "16. 卸载存储节点"
        echo "17. 修改日志等级"
        echo "18. 统计日志文件大小"
        echo "19. 删除存储节点日志"
        echo "=======================备份功能================================"
        echo "21. 备份验证者私钥"
        echo "======================================================="
        echo "20. 更新本脚本"
        read -p "请输入选项（1-21）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) add_wallet ;;
        3) import_wallet ;;
        4) check_balances ;;
        5) check_sync_status ;;
        6) check_service_status ;;
        7) view_logs ;;
        8) uninstall_node ;;
        9) add_validator ;;
        10) delegate_self_validator ;;
        11) transfer_EIP ;;
        12) install_storage_node ;;
        13) check_storage_logs ;;
        14) check_storage_error;;
        15) restart_storage ;;
        16) uninstall_storage_node ;;
        17) change_storage_log_level ;;
        18) storage_logs_disk_usage ;;
        19) delete_storage_logs ;;
        20) update_script ;;
        21) export_priv_validator_key ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done

}

# 显示主菜单
main_menu
