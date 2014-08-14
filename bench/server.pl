#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use Proclet;
use Plack::Loader;
use Plack::Builder;
use Beui::Worker;
use Beui::Web;
use Term::ANSIColor qw/colorstrip/;
use JSON::XS;
use IO::Select;
use POSIX qw(EINTR EAGAIN EWOULDBLOCK :sys_wait_h);

my $basedir = $FindBin::Bin;

my $proclet = Proclet->new;

$proclet->service(
    tag => 'worker',
    code => sub {
        my $worker = Beui::Worker->new($basedir);
        $worker->run
    },
);

my $rfile = "$basedir/data/running";
my $lfile = "$basedir/data/latest";
my $_json = JSON::XS->new->utf8;
my $poll = sub {
    my $env = shift;
    if ( ! -f $rfile && -f $lfile ) {
        open(my $fh, "<", $lfile ) or die "$!";
        my $latest = do { local $/; <$fh> };
        $latest = colorstrip($latest);
        my $json = $_json->encode({t=>$latest});
        return [ 200, [ 'Content-Type'=>'application/json' ], [$json]];
    }
    elsif ( ! -f $rfile ) {
        my $json = $_json->encode({t=>"---"});
        return [ 200, [ 'Content-Type'=>'application/json' ], [$json]];        
    }
    pipe my $logrh, my $logwh
        or die "Died: failed to create pipe:$!\n";
    my $pid = fork;
    if ( ! defined $pid ) {
        die "Died: fork failed: $!\n";
    } 
    elsif ( $pid == 0 ) {
        #child
        close $logrh;
        open STDOUT, '>&', $logwh
            or die "Died: failed to redirect STDOUT\n";
        close $logwh;
        my @s_opt = $^O eq 'darwin' ? () : ('-s','0.3');
        exec('tail',@s_opt,'-n','3000','-f',$lfile);
        die "Died: exec failed: $!\n";
    }
    close $logwh;
    $logrh->blocking(0) or die $!;
    return sub {
        my $responder = shift;
        my $writer = $responder->([ 200, [
            'Transfer-Encoding' => 'chunked',
            'Content-type' => 'application/octet-stream'
        ]]);
        my $s = IO::Select->new($logrh);
        my $stop = 3;
        SLOOP: while ( $stop ) {
            my $r = $s->can_read(0.1);
            if ($r) {
                my $l = sysread($logrh, my $buf, 4096);
                if ( defined $l && $l == 0 ) {
                    # closed
                    last SLOOP;
                }
                elsif ( defined $l ) {
                    # send
                    $buf = colorstrip($buf);
                    my $chunk = $_json->encode({t=>$buf});
                    $chunk .= "\n";
                    $chunk .= ' ' x 8000;
                    my $body = sprintf("%x\r\n", length($chunk));
                    $body .= $chunk . "\r\n";
                    $writer->write($body);
                }
                elsif ( $! != EINTR && $! != EAGAIN && $! != EWOULDBLOCK ) {
                    # error?
                    last SLOOP;
                }
            }
            if ( ! -f $rfile ) {
                $stop = $stop - 1;
            }
        }
        close($logrh);
        kill 'TERM', $pid;
        while (wait == -1) {}
        $writer->write("0\r\n\r\n");
        $writer->close();
    };
};



my $app = Beui::Web->psgi($basedir);
$app = builder {
    enable 'ReverseProxy';
    enable 'Static',
        path => qr!^/(?:(?:css|js|fonts|img)/|favicon\.ico$)!,
        root => $basedir . '/public';
    mount "/poll" => $poll;
    mount "/" => $app;
};

$proclet->service(
    code => sub {
        my $loader = Plack::Loader->load(
            'Starlet',
            port => '5043',
            host => 0,
            max_workers => 5,
        );
        $loader->run($app);
    },
    tag => 'web',
);

$proclet->run;
