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

    # /proc/[pid]/task/[tid]/cmdline -- command line args, passed via exec(2)
    open my $cmdfd, '<', "$_/cmdline";
    my $cmdline = join "\n", <$cmdfd>;
    close $cmdfd;
    $cmdline =~ s/[\n\x00]/ /g; # Yes, there are zeros here
    $cmdline =~ s/(.+[^\s])[\s]*/$1/; # Trim right spaces, not interesting
    $cmdline = substr $cmdline, 0, 60 if length $cmdline > 60;

    # kworkers? what?
    next unless defined $cmdline and length($cmdline) > 0;

    # /proc/[pid]/task/[tid]/stat -- interesting stuff about a process (thread)
    open my $statfd, '<', "$_/stat";
    my $stat = join '', <$statfd>;
    close $statfd;
    # tid (file) status ppid ...
    my ($tid, $ppid) = $stat =~ m{([0-9]+) .*\) . ([0-9]+)};

    # Expect everything when you're dealing with Linux
    next unless defined $tid and defined $ppid;

    $tasks->{$tid} = proc->new($pid, $tid, $ppid, $cmdline);
  }

  $tasks;
}

sub make_tree($$$);
sub make_tree($$$) {
  my ($path, $ppid, $tasks, $proctree) = (
    $_[0], $_[0] =~ m{.*/([^/]+)$}, $_[1], $_[2]);
  for (sort keys %$tasks) {
    if ($tasks->{$_}->{ppid} == $ppid) {
      my $task = $tasks->{$_};
      my $taskpath = "$path/$task->{tid}";
      $proctree->add($taskpath, -text => $task->format);
      make_tree $taskpath, $tasks, $proctree;
    }
  }
}

# main routine

my $mw = MainWindow->new;
$mw->configure(
  -width  => 640,
  -height => 480,
  -title  => 'ProcWatch',
);
my $proctree = $mw->Scrolled('Tree',
  -scrollbars => 'se',
  -separator  => '/',
);
$mw->bind('<Configure>' => sub { # Resize hint
  my ($width, $height) = $mw->geometry =~ m{([0-9]+)x([0-9]+)};
  $proctree->place(-width => $width, -height => $height);
});

sub refresh {
  my %tasks = %{tasks()};

  my $init = $tasks{1};
  die 'Init process not found' unless defined $init;

  $proctree->delete('all');
  $proctree->add(0);
  $proctree->add('0/1', -text => $init->format);

  make_tree '0/1', \%tasks, $proctree;

  for (sort keys %tasks) {
    warn "Unaccessed: " . Dumper $tasks{$_} unless $tasks{$_}->{accessed};
  }

  $proctree->after(1000, \&refresh);
}
$proctree->after(0, \&refresh);

MainLoop;
