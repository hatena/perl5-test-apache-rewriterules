package Test::Apache::RewriteRules::ClientEnvs;
use strict;
use warnings;
our $VERSION = '1.0';
use Exporter::Lite;

our @EXPORT = qw(
    with_request_method
    with_http_cookie
    with_http_header_field
);

our $UserAgent;
our $RequestMethod;
our $Cookies ||= [];
our $HttpHeader ||= [];

my $user_agent_name;
for my $b (
    [
        docomo => 'DoCoMo/1.0/N506iS/c20/TB/W20H11',
    ],
    [
        ezweb => 'KDDI-SA31 UP.Browser/6.2.0.7.3.129 (GUI) MMP/2.0',
    ],
    [
        softbank => 'SoftBank/1.0/910T/TJ001%%SBSerialNumber%% Browser/NetFront/3.3 Profile/MIDP-2.0 Configuration/CLDC-1.1',
    ],
    [
        iphone =>
        'Mozilla/5.0 (iPhone; U; CPU iPhone OS 3_1_3 like Mac OS X; ja-jp) AppleWebKit/528.18 (KHTML, like Gecko) Version/4.0 Mobile/7E18 Safari/528.16',
    ],
    [
        ipod =>
        'Mozilla/5.0 (iPod; U; CPU iPhone OS 3_1_3 like Mac OS X; ja-jp) AppleWebKit/528.18 (KHTML, like Gecko) Version/4.0 Mobile/7E18 Safari/528.16',
    ],
    [
        ipad =>
        'Mozilla/5.0 (iPad; U; CPU OS 3_2 like Mac OS X; ja-jp) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B367 Safari/531.21.10',
    ],
    [
        android =>
        'Mozilla/5.0 (Linux; U; Android 1.6; ja-jp; SonyEricssonSO-01B Build/R1EA018) AppleWebKit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1',
    ],
    [
        dsi =>
        'Opera/9.50 (Nintendo DSi; Opera/507; U; ja)',
    ],
    [
        wii =>
        'Opera/9.30 (Nintendo Wii; U; ; 3642; ja)',
    ],
    [
        firefox =>
        'Mozilla/5.0 (Windows; U; Windows NT 5.1; ja; rv:1.9.1.9) Gecko/20100315 Firefox/3.5.9',
    ],
    [
        safari =>
        'Mozilla/5.0 (Windows; U; Windows NT 5.1; ja-JP) AppleWebKit/531.21.8 (KHTML, like Gecko) Version/4.0.4 Safari/531.21.10',
    ],
    [
        chrome =>
        'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/533.4 (KHTML, like Gecko) Chrome/5.0.375.29 Safari/533.4',
    ],
    [
        opera =>
        'Opera/9.80 (Windows NT 6.0; U; ja) Presto/2.5.22 Version/10.51',
    ],
    [
        ie =>
        'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322; IEMB3; IEMB3)',
    ],
    [
        googlebot =>
        'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
    ],
    [
        googlebot_mobile =>
        'DoCoMo/2.0 N905i(c100;TB;W24H16) (compatible; Googlebot-Mobile/2.1; +http://www.google.com/bot.html)',
    ],
) {
    eval sprintf q{
        sub with_%s_browser (&) {
            my ($code) = @_;
            
            local $UserAgent = q[%s];
            
            local $Test::Builder::Level = $Test::Builder::Level + 1;
            $code->();
        }
        1;
    }, $b->[0], $b->[1] or die $@;
    push @EXPORT, sprintf 'with_%s_browser', $b->[0];
    $user_agent_name->{$b->[0]} = $b->[1];
}

sub with_request_method (&$) {
    my ($code, $method) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    local $RequestMethod = $method;
    $code->();
}

sub with_http_cookie (&$$) {
    my ($code, $name => $value) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    local $Cookies = [@$Cookies, $name => $value];
    $code->();
}

sub with_http_header_field (&$$) {
    my ($code, $name, $body) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    local $HttpHeader = [@$HttpHeader, $name => $body];
    $code->();
}

sub user_agent_name {
    my ($class, $type) = @_;
    return $user_agent_name->{$type};
}

1;
