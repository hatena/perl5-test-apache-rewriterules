package Test::Apache::RewriteRules;
use strict;
use warnings;
our $VERSION = '1.0';
use File::Temp qw(tempfile tempdir);
use Path::Class;
use Test::TCP qw(empty_port);
use LWP::UserAgent;
use HTTP::Request;
use Test::Differences;
use Time::HiRes qw(usleep);

my $data_d = file(__FILE__)->dir->subdir('RewriteRules')->absolute->cleanup;
{
    my $dn = $data_d->stringify;
    1 while $dn =~ s[(^|/)(?!\.\./)[^/]+/\.\.(?=$|/)][$1]g;
    $data_d = dir($dn);
}
my $modules_f = $data_d->file('modules.conf');
my $backend_d = $data_d;
our $HttpdPath = '/usr/sbin/httpd';

sub available {
    return -x $HttpdPath;
}

sub new {
    my $class = shift;
    return bless {
        backends => [],
    }, $class;
}

sub add_backend {
    my ($self, %args) = @_;
    push @{$self->{backends}}, \%args;
}

sub proxy_port {
    my $self = shift;
    return $self->{proxy_port} ||= empty_port();
}

sub proxy_host {
    my $self = shift;
    return 'localhost:' . $self->proxy_port;
}

sub proxy_http_url {
    my $self = shift;
    my $path = shift || q</>;
    $path =~ s[^//[^/]*/][/];
    return q<http://> . $self->proxy_host . $path;
}

sub backend_port {
    my ($self, $backend_name) = @_;
    for (@{$self->{backends}}) {
        return $_->{port} ||= empty_port()
            if $_->{name} eq $backend_name;
    }
    die "Can't find backend |$backend_name|";
}

sub backend_host {
    my ($self, $backend_name) = @_;
    return 'localhost:' . $self->backend_port($backend_name);
}

sub get_backend_name_by_port {
    my ($self, $port) = @_;
    for (@{$self->{backends}}) {
        if ($_->{port} and $_->{port} == $port) {
            return $_->{name};
        }
    }
    return undef;
}

sub rewrite_conf_f {
    my $self = shift;
    if (@_) {
        $self->{rewrite_conf_f} = shift->absolute;
        return unless defined wantarray;
    }
    return $self->{rewrite_conf_f};
}

sub copy_conf_as_f {
    my ($self, $orig_f, $patterns) = @_;
    $patterns ||= [];
    my $conf = $orig_f->slurp;
    while (@$patterns) {
        my $regexp = shift @$patterns;
        $regexp = ref $regexp eq 'Regexp' ? $regexp : qr/\Q$regexp\E/;
        my $new = shift @$patterns;
        my $v = ref $new eq 'CODE' ? $new : sub { $new };
        $conf =~ s/$regexp/$v->()/ge;
    }
    
    my $new_name = $orig_f->basename;
    $new_name =~ s/\.[^.]*//g;
    $new_name .= 'XXXXX';
    (undef, $new_name) = tempfile($new_name, DIR => $self->server_root_dir_name, SUFFIX => '.conf');

    my $new_f = file($new_name);
    my $new_file = $new_f->openw;
    print $new_file $conf;
    close $new_file;
    
    return $new_f;
}

sub server_root_dir_name {
    my $self = shift;
    return $self->{server_root_dir_name} ||= tempdir;
}

sub server_root_d {
    my $self = shift;
    return $self->{server_root_d} ||= dir($self->server_root_dir_name);
}

sub proxy_document_root_d {
    return $backend_d->absolute->cleanup;
}

sub prepare_server_dirs {
    my $self = shift;
    $self->server_root_d->subdir('logs')->mkpath;
}

sub pid_f {
    my $self = shift;
    return $self->{pid_f} ||= $self->server_root_d->file('apache.pid');
}

sub conf_f {
    my $self = shift;
    return $self->{conf_f} ||= $self->server_root_d->file('apache.conf');
}

sub conf_file_name {
    my $self = shift;
    return $self->conf_f->stringify;
}

sub generate_conf {
    my $self = shift;
    
    my $server_root_dir_name = $self->server_root_dir_name;
    $self->prepare_server_dirs;

    my $pid_f = $self->pid_f;
    my $proxy_document_root_d = $self->proxy_document_root_d;
    my $backend_d = $backend_d;
    my $rewrite_conf_f = $self->rewrite_conf_f or die;

    my $proxy_port = $self->proxy_port;

    my $backend_setenvs = '';
    my $backend_vhosts = '';
    for my $backend (@{$self->{backends}}) {
        my $port = $self->backend_port($backend->{name});
        $backend_setenvs .= 'SetEnvIf Request_URI .* ' . $backend->{name} . '=localhost:' . $port . "\n";
        $backend_vhosts .= qq[
Listen $port
<VirtualHost *:$port>
  ServerName $backend->{name}.test:$port
  DocumentRoot $backend_d/
  AddHandler cgi-script .cgi
  <Location $backend_d/>
    Options +ExecCGI
  </Location>
  RewriteEngine on
  RewriteRule /(.*) /url.cgi/\$1 [L]
</VirtualHost>
];
    }

    my $conf_file_name = $self->conf_f->stringify;
    open my $conf_f, '>', $conf_file_name or die "$0: $conf_file_name: $!";
    
    print $conf_f qq[
LogLevel debug

Include "$modules_f"

ServerRoot $server_root_dir_name
PidFile $pid_f
CustomLog logs/access_log "%v\t%h %l %u %t %r %>s %b"
TypesConfig /etc/mime.types

Listen $proxy_port
<VirtualHost *:$proxy_port>
  ServerName proxy.test:$proxy_port
  DocumentRoot $proxy_document_root_d/
  $backend_setenvs

  RewriteRule ^/url\\.cgi/ - [L]

  Include "$rewrite_conf_f"

  Action default-proxy-handler /url.cgi virtual
  SetHandler default-proxy-handler

  <Location /url.cgi>
    SetHandler cgi-script
  </Location>
</VirtualHost>

$backend_vhosts
];

    close $conf_f;
    $self->{conf_generated} = 1;
}

sub conf_generated {
    my $self = shift;
    return $self->{conf_generated};
}

sub start_apache {
    my $self = shift;
    $self->generate_conf unless $self->conf_generated;
    my $conf = $self->conf_file_name or die;
    system $HttpdPath, -f => $conf, -k => 'start';
    if ($? == -1) {
        die "$0: $HttpdPath: $!";
    } elsif ($? & 127) {
        die "$0: $HttpdPath: " . ($? & 127);
    }
    $self->wait_for_starting_apache;
}

sub wait_for_starting_apache {
    my $self = shift;
    my $pid_f = $self->pid_f;
    warn sprintf "Waiting for startng apache process (%s)...\n",
        $self->server_root_dir_name;
    my $i = 0;
    while (not -f $pid_f) {
        usleep 10_000;
        if ($i++ >= 100_00) {
            die "$0: $HttpdPath: Apache does not start in 100 seconds";
        }
    }
}

sub stop_apache {
    my $self = shift;
    my $conf = $self->conf_file_name or die;
    system $HttpdPath, -f => $conf, -k => 'stop';
    $self->wait_for_stopping_apache;
}

sub wait_for_stopping_apache {
    my $self = shift;
    my $pid_f = $self->pid_f;
    warn sprintf "Waiting for stopping apache process (%s)...\n",
        $self->server_root_dir_name;
    my $i = 0;
    while (-f $pid_f) {
        usleep 10_000;
        if ($i++ >= 100_00) {
            die "$0: $HttpdPath: Apache does not end in 100 seconds";
        }
    }
}

sub DESTROY {
    my $self = shift;
    if (-f $self->pid_f) {
        $self->stop_apache;
    }
}


sub get_rewrite_result {
    my ($self, %args) = @_;

    my $url = $self->proxy_http_url($args{orig_path});
    my $method = $Test::Apache::RewriteRules::ClientEnvs::RequestMethod || 'GET';

    my $req = HTTP::Request->new($method => $url);
    my $ua = LWP::UserAgent->new(max_redirect => 0, agent => '');

    my $UA = $Test::Apache::RewriteRules::ClientEnvs::UserAgent;
    if (defined $UA) {
        $UA =~ s/%%SBSerialNumber%%//g;
        $req->header('User-Agent' => $UA);
    }

    if ($args{orig_path} =~ m[^//([^/]*)/]) {
        $req->header(Host => $1);
    }

    my $cookies = $Test::Apache::RewriteRules::ClientEnvs::Cookies || [];
    if (@$cookies) {
        $cookies = [@$cookies];
        my @c;
        while (@$cookies) {
            my $n = shift @$cookies;
            my $v = shift @$cookies;
            push @c, $n . '=' . $v;
        }
        $req->header(Cookie => join '; ', @c);
    }

    my $header = $Test::Apache::RewriteRules::ClientEnvs::HttpHeader || [];
    if (@$header) {
        $header = [@$header];
        my @c;
        while (@$header) {
            my $n = shift @$header;
            my $v = shift @$header;
            $req->header($n => $v);
        }
    }

    my $res = $ua->request($req);

    my $code = $res->code;

    my $result = $code >= 300 ? '' : join "\n", (split /\n/, $res->content)[0, $args{use_path_translated} ? 2 : 1];
    $result =~ s/^(localhost:(\d+))/$1 . q[ (].($self->get_backend_name_by_port($2) || '').q[)]/e;
    $result = $code . ' ' . ($res->header('Location') || '') . "\n" . $result;
    return $result;
}

sub is_host_path {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    
    my ($self, $orig_path, $backend_name, $path, $name) = @_;

    my $result = $self->get_rewrite_result(orig_path => $orig_path, use_path_translated => ($backend_name eq ''));

    my $host = $backend_name
        ? $self->backend_host($backend_name)
        : $self->proxy_host;
    $host .= " ($backend_name)";

    eq_or_diff $result, "200 \n" . $host . "\n" . $path, $name;
}

sub is_redirect {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    
    my ($self, $orig_path, $redirect_url, $name, %args) = @_;

    my $result = $self->get_rewrite_result(orig_path => $orig_path);

    my $code = $args{code} || 302;
    eq_or_diff $result, "$code $redirect_url\n", $name;
}

1;
