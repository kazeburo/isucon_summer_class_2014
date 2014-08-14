package Beui::Worker;

use strict;
use warnings;
use utf8;
use Cwd::Guard qw/cwd_guard/;
use Term::ANSIColor qw/colorstrip/;
use DBIx::Sunny;
use Guard;

sub new {
    my ($class, $base) = @_;
    bless { basedir => $base }, $class;
}

sub datadir {
    my $self = shift;
    $self->{basedir} . '/data';
}


sub sfile {
    my $self = shift;
    $self->{basedir} . '/data/start';
}

sub rfile {
    my $self = shift;
    $self->{basedir} . '/data/running';
}

sub lfile {
    my $self = shift;
    $self->{basedir} . '/data/latest';
}

sub run {
    my $self = shift;
    while (1) {
        if ( -f $self->sfile ) {
            warn "Start Benchmark!";
            $self->run_bench();
            warn "Done Benchmark!";
        }
        sleep 1;
    }
}

sub run_bench {
    my $self = shift;
    # unlink start
    unlink($self->sfile);

    # touch
    open(my $fh, '>', $self->lfile) or die $!;
    truncate($fh,0);
    close($fh);
    open(my $fhr, '>', $self->rfile) or die $!;
    $fhr->print(1);
    close($fhr);

    my $guard = guard {
        unlink($self->rfile);
        unlink($self->sfile);
    };

    my ($result,$exit_code) = $self->bench();
    warn "ERR: $result" if $exit_code != 0;
    my %result;
    for my $line (split /\n/, $result) {
        chomp($line);
        $line = colorstrip($line);
        if ( $line =~ m!^(Result|RawScore|Fails|Score):\s*(.+)$! ) {
            $result{$1}=$2;
        }
    }
    $result{Result} = "-" unless exists $result{Result};
    $result{Score} = "-1" unless exists $result{Score};

    eval {
        my $dbh = DBIx::Sunny->connect(
            "dbi:mysql:database=isumaster;host=localhost;port=3306",
            'isu-master', 'throwing', {
                mysql_auto_reconnect => 1,
            },
        );
        $dbh->query('insert into benchlog (result,score) VALUES (?,?)', $result{Result}, $result{Score});
    };
    warn $@ if $@;
}

sub bench {
    my $self = shift;
    my $guard = cwd_guard($self->{basedir});
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
        open STDERR, '>&', $logwh
            or die "Died: failed to redirect STDERR\n";
        close $logwh;
        exec('./bench','benchmark','--workload','1','--init','/home/isu-user/isucon/init.sh');
        die "Died: exec failed: $!\n";
    }
    close $logwh;
    my $result;
    open(my $fh, '>:unix', $self->lfile) or die $!;
    truncate($fh,0);
    while(<$logrh>){
        warn $_;
        $fh->print($_);
        $result .= $_;
    }
    close($fh);
    close $logrh;
    while (wait == -1) {}
    my $exit_code = $?;
    $exit_code = $exit_code >> 8;
    return ($result, $exit_code);
}


1;

