package test::Test::Apache::RewriteRules;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->parent->subdir('lib')->absolute->cleanup->stringify;
use lib glob file(__FILE__)->dir->parent->parent->parent->subdir('*/lib')->absolute->cleanup->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::Apache::RewriteRules;
use Test::Test::More;

my $rewrite_conf_f = file(__FILE__)->dir->file('apache-rewriterules-rewrite.conf');
my $alias_conf_f = file(__FILE__)->dir->file('apache-rewriterules-alias.conf');

sub _is_host_path : Test(7) {
    my $apache = Test::Apache::RewriteRules->new;
    $apache->add_backend(name => 'BackendFoo');
    $apache->add_backend(name => 'BackendBar');
    $apache->rewrite_conf_f($rewrite_conf_f);

    $apache->start_apache;

    $apache->is_host_path(q</foo/abc> => 'BackendFoo', q</abc>);
    $apache->is_host_path(q</foo/abc?xyz> => 'BackendFoo', q</abc?xyz>);
    $apache->is_host_path(q</bar/abc> => 'BackendBar', q</abc>);
    $apache->is_host_path(q</baz/abc> => '', $apache->proxy_document_root_d . q</baz/abc>);
    $apache->is_host_path(q</baz/abc?foo> => '', $apache->proxy_document_root_d . q</baz/abc?foo>);

    failure_output_like {
        $apache->is_host_path(q</bar/abc> => 'BackendBar', q</ABC>);
    } qr[
# \+---\+------------------------+\+------------------------+\+
# \| Ln\|Got                     +\|Expected                +\|
# \+---\+------------------------+\+------------------------+\+
# \|  1\|200                     +\|200                     +\|
# \|  2\|localhost:\d+ \(BackendBar\) +\|localhost:\d+ \(BackendBar\) +\|
# \*  3\|/abc                    +\|/ABC                    +\*
# \+---\+------------------------+\+------------------------+\+];

    failure_output_like {
        $apache->is_host_path(q</hoge/abc?foo> => '', q</baz/abc?foo>);
    } qr[
# \+---\+--------------------------------\+---\+-------------------+\+
# \| Ln\|Got                             \| Ln\|Expected           +\|
# \+---\+--------------------------------\+---\+-------------------+\+
# \*  1\|302 http://hoge.test/abc\?foo\\n  \*  1\|200\\s\\n        +\*
# \|   \|                                \*  2\|localhost:\d+ \(\) +\*
# \|   \|                                \*  3\|/baz/abc\?foo      +\*
# \+---\+--------------------------------\+---\+-------------------+\+
];
    
    $apache->stop_apache;
}

sub _is_redirect : Test(3) {
    my $apache = Test::Apache::RewriteRules->new;
    $apache->add_backend(name => 'BackendFoo');
    $apache->add_backend(name => 'BackendBar');
    $apache->rewrite_conf_f($rewrite_conf_f);

    $apache->start_apache;

    $apache->is_redirect(q</hoge/abc?foo> => q<http://hoge.test/abc?foo>);
    $apache->is_redirect(q</hoge/301?foo> => q<http://hoge.test/301?foo>, undef, code => 301);
    failure_output_like {
        $apache->is_redirect(q</foo/123> => q<http://hoge.test/abc?foo>);
    } qr[
# \+---\+---------------------------+\+---\+-----------------------------+\+
# \| Ln\|Got                        +\| Ln\|Expected                     +\|
# \+---\+---------------------------+\+---\+-----------------------------+\+
# \*  1\|200\\s\\n                  +\*  1\|302 http://hoge.test/abc\?foo\\n +\*
# \*  2\|localhost:\d+ \(BackendFoo\) +\* +\|                            +\|
# \*  3\|/123                       +\*   \|                             +\|
# \+---\+---------------------------+\+---\+-----------------------------+\+
];
    
    $apache->stop_apache;
}

sub _host_in_path : Test(4) {
    my $apache = Test::Apache::RewriteRules->new;
    $apache->add_backend(name => 'BackendFoo');
    $apache->add_backend(name => 'BackendBar');
    $apache->rewrite_conf_f($rewrite_conf_f);

    $apache->start_apache;

    $apache->is_redirect(q<//abc:40/host/> => q<http://hoge.test/host=abc:40>);
    $apache->is_redirect(q<//abc.test/host/> => q<http://hoge.test/host=abc.test>);
    $apache->is_host_path(q<//abc:40/bhost/> => 'BackendFoo', q</host=abc:40>);
    $apache->is_host_path(q<//abc.test/bhost/> => 'BackendFoo', q</host=abc.test>);

    $apache->stop_apache;
}

sub _alias : Test(2) {
    my $apache = Test::Apache::RewriteRules->new;
    $apache->add_backend(name => 'BackendFoo');
    $apache->rewrite_conf_f($alias_conf_f);

    $apache->start_apache;

    $apache->is_host_path(q</foofoo> => 'BackendFoo', q</foofoo>);
    $apache->is_host_path(q</local/foofoo> => '', q</path/to/local/repository/foofoo>);

    $apache->stop_apache;
}

sub _copy_conf_as_f_asis : Test(2) {
    my $apache = Test::Apache::RewriteRules->new;
    my $new_f = $apache->copy_conf_as_f($rewrite_conf_f);
    isnt $new_f->stringify, $rewrite_conf_f->stringify;
    is scalar $new_f->slurp, scalar $rewrite_conf_f->slurp;
}

sub _copy_conf_as_f_changed : Test(2) {
    my $apache = Test::Apache::RewriteRules->new;
    my $new_f = $apache->copy_conf_as_f($rewrite_conf_f, [
        RewriteRule => '# RewriteRule',
    ]);
    isnt $new_f->stringify, $rewrite_conf_f->stringify;
    my $expected = $rewrite_conf_f->slurp;
    $expected =~ s/RewriteRule/# RewriteRule/g;
    is scalar $new_f->slurp, $expected;
}

sub _copy_conf_as_f_changed_regexp : Test(2) {
    my $apache = Test::Apache::RewriteRules->new;
    my $new_f = $apache->copy_conf_as_f($rewrite_conf_f, [
        qr/Backend(\w+)/ => sub { $1 },
    ]);
    isnt $new_f->stringify, $rewrite_conf_f->stringify;
    my $expected = $rewrite_conf_f->slurp;
    $expected =~ s/BackendFoo/Foo/g;
    $expected =~ s/BackendBar/Bar/g;
    is scalar $new_f->slurp, $expected;
}

sub _copy_conf_as_f_changed_rules : Test(2) {
    my $apache = Test::Apache::RewriteRules->new;
    my $new_f = $apache->copy_conf_as_f($rewrite_conf_f, [
        qr/RewriteEngine.*/ => '',
        qr/RewriteRule.*/ => '',
        qr/SetEnvIf.*/ => '',
        qr/#.*/ => '',
        qr/\s+/ => '***',
    ]);
    isnt $new_f->stringify, $rewrite_conf_f->stringify;
    is scalar $new_f->slurp, '***';
}

__PACKAGE__->SKIP_CLASS('Apache is not available') unless Test::Apache::RewriteRules->available;

__PACKAGE__->runtests;

1;
