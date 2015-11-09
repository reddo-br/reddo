## reddo

jrubyによるredditブラウザ

### 実行に必要なもの

jre 8u51 以上

### ビルド方法

rawrが必要です。

    jruby -S gem install rawr --source http://gems.neurogami.com

リポジトリに入ってない、必要なファイルを取得します。

    jruby -S rake rawr:get:current-jruby
    
    # jrubyのサイトからjruby-complete-9.0.1.0.jar を取ってきてコピーします
    # 9.0.3.0では現在動作しません
    cp jruby-complete-9.0.1.0.jar lib/java/jruby-complete.jar

    jruby -S gem install -i ./gem jrubyfx --version "= 1.1.1" --no-rdoc --no-ri
    jruby -S gem install -i ./gem redd --version "= 0.7.7" --no-rdoc --no-ri
    jruby -S gem install -i ./gem json --no-rdoc --no-ri
    jruby -S gem install -i ./gem css_parser --no-rdoc --no-ri

gemフォルダに取得した、jrubyfx-fxmlloader-0.4にはパッチを当てといて下さい

    patch -p0 < jrubyfx-fxmlloader-0.4-java-8u60.patch

パッケージをビルドします

    jruby -S rake rawr:clean
    jruby -S rake rawr:jar
    jruby -S rake rawr:bundle:exe
    jruby -S rake rawr:bundle:app

mac用パッケージを修正するファイルを追加しときます

    cp misc/Reddo-mac package/osx/reddo.app/Contents/MacOS/Reddo
    cp misc/Info.plist package/osx/reddo.app/Contents/

windowsのjrubyでは、jarファイル内でのrequire_relativeが正常に動かない関係で、
windows用パッケージには、gemディレクトリ以下をそのままコピーしておいて下さい。とりあえず動きます;

    cp -r gem package/windows


