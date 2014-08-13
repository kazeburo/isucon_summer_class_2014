ISUCON夏期講習サーバの設定など

# サーバ

とりあえず今はここで設定中

http://ec2-54-250-115-149.ap-northeast-1.compute.amazonaws.com/

sshは `ssh ec2-user@ec2-54-250-115-149.ap-northeast-1.compute.amazonaws.com` になる

# setup メモ

```
sudo adduser isu-user
echo "isu-user       ALL=(ALL)       NOPASSWD: ALL" | sudo tee /etc/sudoers.d/isu-user 
sudo su - isu-user
```

```
sudo yum install -y make gcc git curl tar bzip2 patch openssl-devel memcached httpd24 httpd24-tools python-setuptools  strace libxml2-devel pigz
yum install -y http://ftp.jaist.ac.jp/pub/mysql/Downloads/MySQL-5.5/MySQL-client-5.5.39-2.linux2.6.x86_64.rpm \
 http://ftp.jaist.ac.jp/pub/mysql/Downloads/MySQL-5.5/MySQL-devel-5.5.39-2.linux2.6.x86_64.rpm \
 http://ftp.jaist.ac.jp/pub/mysql/Downloads/MySQL-5.5/MySQL-server-5.5.39-2.linux2.6.x86_64.rpm \
 http://ftp.jaist.ac.jp/pub/mysql/Downloads/MySQL-5.5/MySQL-shared-5.5.39-2.linux2.6.x86_64.rpm \
 http://ftp.jaist.ac.jp/pub/mysql/Downloads/MySQL-5.5/MySQL-shared-compat-5.5.39-2.linux2.6.x86_64.rpm
sudo easy_install http://pypi.python.org/packages/source/s/supervisor/supervisor-3.0a12.tar.gz
sudo mkdir /var/log/supervisor
sudo /sbin/chkconfig memcached on
sudo /sbin/chkconfig mysql on
sudo /sbin/chkconfig httpd on
```

### xbuild

```
git clone https://github.com/tagomoris/xbuild.git
./xbuild/perl-install 5.20.0 ~/local/perl-5.20
./xbuild/ruby-install 2.1.2 ~/local/ruby-2.1.2
./xbuild/node-install v0.10.30 ~/local/node-v0.10
./xbuild/python-install 3.4.1 ~/local/python-3.4.1
export PATH=/home/isu-user/local/perl-5.20/bin:$PATH
export PATH=/home/isu-user/local/ruby-2.1.2/bin:$PATH
export PATH=/home/isu-user/local/node-v0.10/bin:$PATH
export PATH=/home/isu-user/local/python-3.4.1/bin:$PATH
export PATH=/home/isu-user/local/go/bin:$PATH
export GOPATH=/home/isu-user/local/go/bin
export GOROOT=/home/isu-user/local/go
```

### bashrcにも設定

```
cat <'EOF' >> ~/.bashrc
export PATH=/home/isu-user/local/perl-5.20/bin:$PATH
export PATH=/home/isu-user/local/ruby-2.1.2/bin:$PATH
export PATH=/home/isu-user/local/node-v0.10/bin:$PATH
export PATH=/home/isu-user/local/python-3.4.1/bin:$PATH
export PATH=/home/isu-user/local/go/bin:$PATH
export GOPATH=/home/isu-user/local/go/bin
export GOROOT=/home/isu-user/local/go
EOF
```

### golang

```
wget http://golang.org/dl/go1.3.linux-amd64.tar.gz
tar zxf go1.3.linux-amd64.tar.gz
mv go1.3.linux-amd64 /home/local/go
```


### コードのgit clone

```
git clone git@github.com:kazeburo/isucon_summer_class_2014.git isucon
```

README.mdを参考に各言語のアプリケーションセットアップ。

### mysql、apache、supervisorの設定

```
sudo cp -a isucon/config/my.cnf /etc/my.cnf
sudo cp -a isucon/config/isucon.conf /etc/httpd/conf.d/isucon.conf
sudo cp -a isucon/config/supervisord/supervisord.conf /etc/supervisord.conf 
sudo cp -a isucon/config/supervisord/supervisord.init /etc/init.d/supervisord
sudo chmod +x /etc/init.d/supervisord
sudo /sbin/chkconfig --add supervisordsudo /sbin/chkconfig supervisord on
```

### MySQL

```
CREATE DATABASE isucon;
CREATE USER 'isucon'@'%' IDENTIFIED BY '';
CREATE USER 'isucon'@'localhost' IDENTIFIED BY '';
CREATE USER 'isu-user'@'%' IDENTIFIED BY '';
CREATE USER 'isu-user'@'localhost' IDENTIFIED BY '';
GRANT ALL ON isucon.* TO 'isucon'@'%';
GRANT ALL ON isucon.* TO 'isucon'@'localhost';
GRANT ALL ON isucon.* TO 'isu-user'@'%';
GRANT ALL ON isucon.* TO 'isu-user'@'localhost';

CREATE DATABASE isumaster;
CREATE USER 'isu-master'@'%' IDENTIFIED BY 'throwing';
CREATE USER 'isu-master'@'localhost' IDENTIFIED BY 'throwing';
GRANT ALL ON isumaster.* TO 'isu-master'@'localhost';
GRANT ALL ON isumaster.* TO 'isu-master'@'%';
```

### 起動

```
sudo service https start
sudo service mysql start
sudo service supervisor start
```

### ベンチマークツールのセットアップ

README.mdを参考にセットアップ

# ベンチマークの設定と実行

1. 起動したインスタンスの TCP 80 で Web アプリケーションが起動しています
  * 初期設定では Perl 実装が起動している状態です
  * PHP実装のみ他言語と起動方法が異なるため、`/home/isu-user/isucon/webapp/php/README.md` を参照してください
  * SignInのためのテスト用アカウントは username: isucon1 password: isucon1 を使用してください

2. ベンチマークをテスト実行するためには、下記コマンドを入力してください

```
$ cd /home/isu-user/isucon/bench
$ ./bench test --workload 2
```

テスト実行の場合は、初期設定時に投入されているデータベースのデータはリセットされません

3. 本番計測を行う場合は、以下のコマンドを入力してください

```
$ ./bench benchmark [--init /path/to/script] [--workload N]
```

* 初期設定時と同様の状態にデータベースがリセットされます。そのため、実行開始までに数十秒程度の時間がかかります
  * データベースリセットのためには以下の条件を満たす必要があります
    * MySQL が起動している
    * user `isucon`, password なしで `isucon` データベースに接続可能
    * MySQL の `root` ユーザのパスワードは `root` です
* `--init` 引数に任意の実行可能なコマンド(スクリプトなど)を指定することで、データベースリセット後に任意の処理を行うことができます
  * MySQL 以外のストレージにデータを移すなどの処理はここで行ってください
  * ただしコマンドの実行終了を待つのは実時間で60秒までで、それ以上経過すると強制終了されます
* `--workload` は省略可能で、デフォルト 1 です
  * 2,3,4...と数値を増やすごとにベンチマークで掛けられる負荷が上がります
  * スコアの集計は `workload` の値によらず、表示されたものが最終結果となります
