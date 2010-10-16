package test::Test::Apache::RewriteRules::ClientEnvs;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->parent->subdir('lib')->stringify;
use lib glob file(__FILE__)->dir->parent->parent->parent->subdir('*/lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::Apache::RewriteRules;
use Test::Apache::RewriteRules::ClientEnvs;
use Test::Test::More;

my $rewrite_conf_f = file(__FILE__)->dir->file('apache-rewriterules-rewrite.conf');

sub _ua : Test(17) {
    my $apache = Test::Apache::RewriteRules->new;
    $apache->add_backend(name => 'BackendFoo');
    $apache->add_backend(name => 'BackendBar');
    $apache->rewrite_conf_f($rewrite_conf_f);

    $apache->start_apache;

    $apache->is_host_path(q</ua> => 'BackendFoo', q</>);
    with_docomo_browser {
        $apache->is_host_path(q</ua> => 'BackendFoo', q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('docomo'));
    };
    with_ezweb_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('ezweb');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_softbank_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('softbank');
        $path =~ s/%%SBSerialNumber%%//g;
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_iphone_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('iphone');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_ipod_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('ipod');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_ipad_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('ipad');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_android_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('android');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_dsi_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('dsi');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_wii_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('wii');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_firefox_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('firefox');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_opera_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('opera');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_chrome_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('chrome');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_safari_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('safari');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_ie_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('ie');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_googlebot_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('googlebot');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };
    with_googlebot_mobile_browser {
        my $path = q</> . Test::Apache::RewriteRules::ClientEnvs->user_agent_name('googlebot_mobile');
        $path =~ s/ /%20/g;
        $apache->is_host_path(q</ua> => 'BackendFoo', $path);
    };

    $apache->stop_apache;
}

sub _request_method : Test(6) {
    my $apache = Test::Apache::RewriteRules->new;
    $apache->add_backend(name => 'BackendFoo');
    $apache->add_backend(name => 'BackendBar');
    $apache->rewrite_conf_f($rewrite_conf_f);

    $apache->start_apache;

    $apache->is_host_path(q</bmethod> => 'BackendFoo', q</method=GET>);
    $apache->is_redirect(q</pmethod> => q<http://hoge.test/method=GET>);
    with_request_method {
        $apache->is_host_path(q</bmethod> => 'BackendFoo', q</method=GET>);
        $apache->is_redirect(q</pmethod> => q<http://hoge.test/method=GET>);
    } 'GET';
    with_request_method {
        $apache->is_host_path(q</bmethod> => 'BackendFoo', q</method=POST>);
        $apache->is_redirect(q</pmethod> => q<http://hoge.test/method=POST>);
    } 'POST';

    $apache->stop_apache;
}

sub _with_cookie : Test(6) {
    my $apache = Test::Apache::RewriteRules->new;
    $apache->add_backend(name => 'BackendFoo');
    $apache->add_backend(name => 'BackendBar');
    $apache->rewrite_conf_f($rewrite_conf_f);

    $apache->start_apache;

    $apache->is_host_path(q</bcookie> => 'BackendFoo', q</>);
    with_http_cookie {
        $apache->is_host_path(q</bcookie> => 'BackendFoo', q</a=1>);
        with_http_cookie {
            $apache->is_host_path(q</bcookie> => 'BackendFoo', q</a=1;%20AbX=abacae>);
            with_http_cookie {
                $apache->is_host_path(q</bcookie> => 'BackendFoo', q</a=1;%20AbX=abacae;%20a=2>);
            } a => 2;
        } AbX => 'abacae';
        $apache->is_host_path(q</bcookie> => 'BackendFoo', q</a=1>);
    } a => 1;
    $apache->is_host_path(q</bcookie> => 'BackendFoo', q</>);

    $apache->stop_apache;
}

sub _with_http_header_field : Test(3) {
    my $apache = Test::Apache::RewriteRules->new;
    $apache->add_backend(name => 'BackendFoo');
    $apache->add_backend(name => 'BackendBar');
    $apache->rewrite_conf_f($rewrite_conf_f);

    $apache->start_apache;

    $apache->is_host_path(q</bxabc> => 'BackendFoo', q</>);
    with_http_header_field {
        $apache->is_host_path(q</bxabc> => 'BackendFoo', q</aba%20x>);
    } 'X-abc' => 'aba x';
    $apache->is_host_path(q</bcookie> => 'BackendFoo', q</>);

    $apache->stop_apache;
}

__PACKAGE__->SKIP_CLASS('Apache is not available') unless Test::Apache::RewriteRules->available;

__PACKAGE__->runtests;

1;
