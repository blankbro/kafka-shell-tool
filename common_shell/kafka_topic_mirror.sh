#!/bin/bash

# 默认值
kafka_bootstrap_servers=""
backup_file=""
create_input_file=""
kafka_bin_dir="."
operation=""
topic_grep=""

# 解析命令行参数
# $# 是一个特殊变量，表示命令行参数的数量。-gt 是一个比较运算符，表示大于。
while [[ $# -gt 0 ]]; do
    # 将当前处理的命令行参数赋值给变量 key
    key="$1"

    case $key in
    --kafka-bin-dir)
        kafka_bin_dir="$2"
        shift
        shift
        ;;
    --bootstrap-server)
        kafka_bootstrap_servers="$2"
        # shift 命令将已处理的参数移除, 第一次移除key, 第二次移除对应的值
        shift
        shift
        ;;
    --operation)
        operation="$2"
        shift
        shift
        ;;
    --backup_file)
        backup_file="$2"
        shift
        shift
        ;;
    --create_input_file)
        create_input_file="$2"
        shift
        shift
        ;;
    --topic_grep)
        topic_grep="$2"
        shift
        shift
        ;;
    *)
        shift
        ;;
    esac
done

# 备份 Kafka topic 数据函数
backup_topic() {
    echo "备份 Kafka topic 数据开始..."

    # 获取 Kafka topic 列表
    topics=$($kafka_bin_dir/kafka-topics.sh --bootstrap-server $kafka_bootstrap_servers --list)
    topic_total_count=$(echo $topics | wc -w)
    echo "topic 总量: $topic_total_count"

    # 清空输出文件
    echo "" >$backup_file

    # 遍历每个 topic
    index=1
    for topic in $topics; do
        echo "[$index/$topic_total_count] 开始处理 $topic"
        if [[ $topic == "__consumer_offsets" || $topic == "ATLAS_ENTITIES" || $topic == "__amazon_msk_canary" ]]; then
            echo "跳过 $topic"
            index=$((index + 1))
            continue
        elif [[ $topic_grep != "" && $topic != *"$topic_grep"* ]]; then
            echo "跳过不匹配的 Topic: $topic"
            index=$((index + 1))
            continue
        fi

        # 将数据写入输出文件
        # echo $kafka_bin_dir/kafka-topics.sh --bootstrap-server $kafka_bootstrap_servers --describe --topic $topic | grep "PartitionCount" | awk '{print $1,$2}{print $3,$4} {print $5,$6}'
        $kafka_bin_dir/kafka-topics.sh --bootstrap-server $kafka_bootstrap_servers --describe --topic $topic | grep "PartitionCount" | awk '{print $1,$2}{print $3,$4} {print $5,$6}' >>$backup_file

        # 空行隔开
        echo "" >>$backup_file
        index=$((index + 1))
    done

    echo "备份 Kafka topic 数据完成，并已写入文件: $backup_file"
}


# 创建 Kafka topic 数据函数
create_topic() {
    echo "创建 Kafka topic 数据开始..."

    # 读取备份文件内容
    while IFS= read -r line; do
        # 提取 topic 名称、分区和副本因子
        if [[ $line == "Topic: "* ]]; then
            topic=${line#"Topic: "}
        elif [[ $line == "PartitionCount: "* ]]; then
            partitions=${line#"PartitionCount: "}
        elif [[ $line == "ReplicationFactor: "* ]]; then
            replication_factor=${line#"ReplicationFactor: "}

            # 创建 topic
            echo "$topic parition:[$partitions], replication_factor:[$replication_factor] 开始创建"
            # $kafka_bin_dir/kafka-topics.sh --bootstrap-server $kafka_bootstrap_servers --create --topic $topic --partitions $partitions --replication-factor $replication_factor
            echo "$topic 完成创建"
        fi
    done <$create_input_file

    echo "创建 Kafka topic 数据完成。"
}

if [[ -z $kafka_bootstrap_servers ]]; then
    echo "请提供 Kafka 集群信息"
    exit
fi

# 根据参数执行对应功能
if [[ $operation == "backup_topic" ]]; then
    backup_topic
elif [[ $operation == "create_topic" ]]; then
    create_topic
else
    echo "请提供正确的参数"
fi
