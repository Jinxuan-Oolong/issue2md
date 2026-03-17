#!/bin/bash
# 僅僅負責把過去 10 條 commit 提取出來，不讓大模型去猜 Git 指令
git log -n 10 --pretty=format:"%h - %s (%an)"