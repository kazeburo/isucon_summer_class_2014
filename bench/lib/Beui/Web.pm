package Beui::Web;

use strict;
use warnings;
use utf8;
use Kossy;


get '/' => sub {
    my ( $self, $c )  = @_;
    $c->render('index.tx');
};

get '/score' => sub {
    my ( $self, $c )  = @_;

    my $dbh = DBIx::Sunny->connect(
        "dbi:mysql:database=isumaster;host=localhost;port=3306",
        'isu-master', 'throwing', {
            mysql_auto_reconnect => 1,
        },
    );
    my $latest = $dbh->select_row('SELECT * FROM benchlog ORDER BY created_at DESC LIMIT 1');
    my $best_score = $dbh->select_one('SELECT MAX(score) FROM benchlog');
    $latest = { 
        score => '-1',
        result => '-',
    } if ! defined $latest;
    $best_score = -1 if ! defined $best_score
    $c->render_json({
        latest_score => $latest->{score},
        latest_result => $latest->{result},
        best_score => $best_score
    });
};

post '/start' => sub {
    my ( $self, $c )  = @_;    
    my $sfile = $self->root_dir."/data/start";
    open(my $fhr, '>', $sfile) or die $!;
    $fhr->print(1);
    close($fhr);
    sleep(1);
    $c->render_json({
        location => $c->req->uri_for('/')->as_string
    });
};


1;

