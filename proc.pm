#!/usr/bin/perl
# Made by kk

package proc;

sub new {
  my ($self, $pid, $tid, $ppid, $cmdline) = @_;
  $ppid = $pid unless $tid == $pid;
  bless {pid     => $pid,
         tid     => $tid,
         ppid    => $ppid,
         cmdline => $cmdline,
         accessed => 0,
       }, $self;
}

sub format {
  my $self = $_[0];
  $self->{accessed} = 1;
  "pid: $self->{pid}, tid: $self->{tid} // $self->{cmdline}";
}

1;
