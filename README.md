## reddo

jrubyによるredditブラウザ

### 実行に必要なもの

jre 8u101 以上を奨励

### ビルド方法

jdkが必要です。

jrubyが必要です。9.1.3.0 , 9.1.4.0では現在ビルドがうまくできません。9.1.2.0以前の適当なバージョンを用意してください。

以下はlinuxでのコマンド例です。

パッケージ作成用のライブラリとしてrawrが必要です。

    jruby -S gem install rawr --source http://gems.neurogami.com

リポジトリに入ってない、必要なファイルを取得します。

    jruby -S rake rawr:get:current-jruby
    
    # jrubyのサイトからjruby-complete-9.1.3.0.jar を取ってきてコピーします
    # パッケージに含めるjrubyは現在9.1.3.0を使っています
    cp jruby-complete-9.1.3.0.jar lib/java/jruby-complete.jar

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

いくつかのファイルを手動で追加、上書きしてください

    cp misc/Reddo-mac package/osx/reddo.app/Contents/MacOS/Reddo
    cp misc/Info.plist package/osx/reddo.app/Contents/
    cp misc/reddo.l4j.ini package/windows/
    cp misc/reddo.sh package/jar

windowsのjrubyでは、jarファイル内でのrequire_relativeが正常に動かない関係で、
windows用パッケージには、gemディレクトリ以下をそのままコピーしておいて下さい。とりあえず動きます;

    cp -r gem package/windows

