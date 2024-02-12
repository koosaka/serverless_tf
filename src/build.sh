#!/bin/bash

# 各サブディレクトリに対してループ
for dir in */ ; do
    # index.tsが存在するかチェック
    if [[ -f "$dir/index.ts" ]]; then
        # 出力先ディレクトリの作成
        mkdir -p "./dist/${dir}"
        # esbuildコマンドでビルド
        esbuild "$dir/index.ts" --bundle --minify --sourcemap --platform=node --target=es2020 --outfile="./dist/${dir}/index.js"
    fi
done
