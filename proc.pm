#!/usr/bin/perl
# Made by kk

package proc;

sub new {
  my ($self, $pid, $lwp, $ppid, $cmdline) = @_;
  $ppid = $pid unless $lwp == $pid;
  bless {pid     => $pid,
         lwp     => $lwp,
         ppid    => $ppid,
         cmdline => $cmdline,
         accessed => 0,
       }, $self;
}

sub format {
  my $self = $_[0];
  $self->{accessed} = 1;
  "pid: $self->{pid}, lwp: $self->{lwp} // $self->{cmdline}";
}

1;
