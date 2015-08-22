## reddo

jrubyによるredditブラウザ

### 実行に必要なもの

jre 8u51 以上

### ビルド方法

rawrが必要です。

    jruby -S gem install rawr --source http://gems.neurogami.com

リポジトリに入ってない、必要なファイルを取得します。

    jruby -S rake rawr:get:current-jruby
    # 手動で再審のjruby-complete-*.jar を探してきて、lib/javaに入れた方がいいかも

    jruby -S gem install -i ./gem jrubyfx --version "= 1.1.1" --no-rdoc --no-ri
    jruby -S gem install -i ./gem redd --version "= 0.7.5" --no-rdoc --no-ri
    jruby -S gem install -i ./gem json --no-rdoc --no-ri

gemフォルダに取得した、jrubyfx-fxmlloader-0.4にはパッチを当てといて下さい

    patch -p0 < jrubyfx-fxmlloader-0.4-java-8u60.patch

パッケージをビルドします

    jruby -S rake rawr:clean
    jruby -S rake rawr:jar
    jruby -S rake rawr:bundle:exe
    jruby -S rake rawr:bundle:app

windowsのjrubyでは、jarファイル内でのrequire_relativeが正常に動かない関係で、
windows用パッケージには、gemディレクトリ以下をそのままコピーしておいて下さい。とりあえず動きます;

    cp -r gem package/windows


