#!/usr/bin/perl
# Made by kk

use Data::Dumper;
use Tk;
use Tk::Tree;
use strict;
use warnings;

use lib '.';
use proc;

sub tasks {
  my $tasks = {};

  for (</proc/[0-9]*/task/*>) {
    next unless defined (my ($pid) = m{/proc/([0-9]+)/});

    # /proc/[pid]/task/[lwp]/cmdline -- command line args, passed via exec(2)
    open my $cmdfd, '<', "$_/cmdline" or next;
    my $cmdline = join "\n", <$cmdfd>;
    close $cmdfd;
    $cmdline =~ s/[\n\x00]/ /g; # Yes, there are zeros here
    $cmdline =~ s/(.+[^\s])[\s]*/$1/; # Trim right spaces, not interesting
    $cmdline = substr $cmdline, 0, 60 if length $cmdline > 60;

    # kworkers? what?
    next unless defined $cmdline and length($cmdline) > 0;

    # /proc/[pid]/task/[lwp]/stat -- interesting stuff about a process (thread)
    open my $statfd, '<', "$_/stat" or next;
    my $stat = join '', <$statfd>;
    close $statfd;
    # lwp (file) status ppid ...
    my ($lwp, $ppid) = $stat =~ m{([0-9]+) .*\) . ([0-9]+)};

    # Expect everything when you're dealing with Linux
    next unless defined $lwp and defined $ppid;

    $tasks->{$lwp} = proc->new($pid, $lwp, $ppid, $cmdline);
  }

  $tasks;
}

sub make_tree($$$);
sub make_tree($$$) {
  my ($path, $ppid, $tasks, $proctree) = (
    $_[0], $_[0] =~ m{.*?([^/]+)$}, $_[1], $_[2]);
  for (sort keys %$tasks) {
    if ($tasks->{$_}->{ppid} == $ppid) {
      my $task = $tasks->{$_};
      my $taskpath = "$path/$task->{lwp}";
      $proctree->add($taskpath, -text => $task->format);
      make_tree $taskpath, $tasks, $proctree;
    }
  }
}

# main routine

sub show_process_menu($);

my $mw = MainWindow->new;
$mw->configure(
  -width  => 640,
  -height => 480,
  -title  => 'ProcWatch',
);
my $proctree = $mw->Scrolled('Tree',
  -scrollbars => 'se',
  -separator  => '/',
  -command    => sub { show_process_menu $_[0] =~ s{.*/}{}r },
);
$mw->bind('<Configure>' => sub { # Resize hint
  my ($width, $height) = $mw->geometry =~ m{([0-9]+)x([0-9]+)};
  $proctree->place(-width => $width, -height => $height);
});

my $called;
sub refresh {
  my %tasks = %{tasks()};

  my $init = $tasks{1};
  die 'Init process not found' unless defined $init;

  $proctree->delete('all');
  $proctree->add('1', -text => $init->format);

  make_tree '1', \%tasks, $proctree;

  for (sort keys %tasks) {
    warn "Unaccessed: " . Dumper $tasks{$_} unless $tasks{$_}->{accessed};
  }

  $proctree->after(1000, \&refresh);
}
$proctree->after(0, \&refresh);

########################### ################### #############################
############# ############### #################### ############## ###########

sub show_signal_menu($$) {
  my ($mw, $proc) = @_;
  my $sw = $mw->Toplevel(-title => "ProcWatch [$proc]: send signal");
  my $sigframe = $sw->Frame;

  my %signals = reverse ( # Copy-paste signal(7), linux-specific
    SIGHUP   =>   1, #    Term    Hangup detected on controlling terminal
                     #            or death of controlling process
    SIGINT   =>   2, #    Term    Interrupt from keyboard
    SIGQUIT  =>   3, #    Core    Quit from keyboard
    SIGILL   =>   4, #    Core    Illegal Instruction
    SIGABRT  =>   6, #    Core    Abort signal from abort(3)
    SIGFPE   =>   8, #    Core    Floating-point exception
    SIGKILL  =>   9, #    Term    Kill signal
    SIGSEGV  =>  11, #    Core    Invalid memory reference
    SIGPIPE  =>  13, #    Term    Broken pipe: write to pipe with no
                     #            readers; see pipe(7)
    SIGALRM  =>  14, #    Term    Timer signal from alarm(2)
    SIGTERM  =>  15, #    Term    Termination signal
    SIGUSR1  =>  10, #    Term    User-defined signal 1
    SIGUSR2  =>  12, #    Term    User-defined signal 2
    SIGCHLD  =>  17, #    Ign     Child stopped or terminated
    SIGCONT  =>  18, #    Cont    Continue if stopped
    SIGSTOP  =>  19, #    Stop    Stop process
    SIGTSTP  =>  20, #    Stop    Stop typed at terminal
    SIGTTIN  =>  21, #    Stop    Terminal input for background process
    SIGTTOU  =>  22, #    Stop    Terminal output for background process
  );

  $sw->Label(-text => "Send a signal to $proc:")->pack;
  my $status;
  my $prev_btn = '%0';
  for my $s (sort {$a<=>$b} keys %signals) {
    $prev_btn = $sigframe->Button(
      -command => sub {
        my $res = (kill $s, $proc) == 1 ? 'ok' : 'fail';
        $status->configure(-text => "Operation status: $res");
      },
      -text    => "$signals{$s} <$s>",
    )->form(-top => $prev_btn, -left => '%0', -right => '%100');
  }
  $sigframe->pack;
  $status = $sw->Label->pack;
}

sub show_process_menu($) {
  my ($proc, $prev) = ($_[0], '%0');
  my $pw = $mw->Toplevel(-title => "ProcWatch [$proc]");
  $prev = $pw->Label(-text => "Control $proc:")->form(
    -left => '%0', -right => '%100', -top => $prev,);
  $prev = $pw->Button(
    -command => sub { show_signal_menu $pw, $proc },
    -text    => 'Signalize',
  )->form(-left => '%0', -right => '%100', -top => $prev,);
  $prev = $pw->Button(
    -command => sub {
      open my $stfd, '<', "/proc/$proc/status" or return;
      my $st = join '', <$stfd>;
      close $stfd;
      my $statusfile = $pw->Toplevel(-title => "ProcWatch [$proc]: status");
      my $statustext = $statusfile->Scrolled('Text', -scrollbars => 'se');
      $statustext->Insert($st);
      $statustext->configure(-state => 'disabled');
      $statustext->pack;
    },
    -text    => 'Show status file',
  )->form(-left => '%0', -right => '%100', -top => $prev);
}

MainLoop;
