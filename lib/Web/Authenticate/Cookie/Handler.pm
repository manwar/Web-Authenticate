use strict;
package Web::Authenticate::Cookie::Handler;
use Mouse;
use CGI;
use CGI::Cookie;
use Carp;
#ABSTRACT: The default implementation of Web::Authentication::Cookie::Handler::Role

with 'Web::Authenticate::Cookie::Handler::Role';

=method cookie_prefix

Sets the prefix to go before cookie names. Default is 'web_authenticate_'.

=cut

has cookie_prefix => (
    isa => 'Str',
    is => 'ro',
    required => 1,
    default => 'web_authenticate_',
);

=method domain

See L<CGI::Cookie>. Default is undef.

=cut

has domain => (
    is => 'ro',
    default => undef,
);

=method path

See L<CGI::Cookie>. Default is undef.

=cut

has path => (
    is => 'ro',
    default => undef,
);

=method secure

See L<CGI::Cookie>. Default is undef.

=cut

has secure => (
    isa => 'Bool',
    is => 'ro',
    default => undef,
);

=method httponly

See L<CGI::Cookie>. Default is undef.

=cut

has httponly => (
    isa => 'Bool',
    is => 'ro',
    default => undef,
);

=method samesite

See L<CGI::Cookie>. Default is undef.

=cut

has samesite => (
    is => 'ro',
    default => undef,
);

=method set_cookie

Creates a session for user and sets it on the browser. expires must be the number of seconds from now
when the cookie should expire.

    $cookie_handler->set_cookie($name, $value, $expires_in_seconds);

=cut

sub set_cookie {
    my ($self, $name, $value, $expires_in_seconds) = @_;
    croak "must provide name" unless $name;
    croak "must provide value" unless $value;
    croak "expires_in_seconds must be positive" unless $expires_in_seconds > 0;
    
    $self->_bake_cookie($name, $value, $expires_in_seconds);
}

=method get_cookie

Gets the value of the cookie with name. Returns undef if there is no cookie with that name, or it has expired.

    my $cookie_value = $cookie_handler->get_cookie($name);


=cut

sub get_cookie {
    my ($self, $name) = @_;
    croak "must provide name" unless $name;

    my $q = CGI->new;
    return $q->cookie($self->_get_cookie_name($name));
}

=method delete_cookie

Deletes cookie with name if it exists.

    $cookie_handler->delete_cookie($name);

=cut

sub delete_cookie {
    my ($self, $name) = @_;
    croak "must provide name" unless $name;

    $self->_bake_cookie($name, '', -123456789);
}

sub _get_cookie_name { shift->cookie_prefix . shift } 

sub _bake_cookie {
    my ($self, $name, $value, $expires_in_seconds) = @_;

    my $maybe_plus = $expires_in_seconds > 0 ? '+' : '';
    my $expires_time = "$maybe_plus$expires_in_seconds" . 's';
    my $cookie = CGI::Cookie->new(
        -name => $self->_get_cookie_name($name),
        -value => $value,
        -expires => $expires_time,
        '-max-age' => $expires_time,
        -domain => $self->domain,
        -path => $self->path,
        -secure => $self->secure,
        -httponly => $self->httponly,
        -samesite => $self->samesite,
    );
    print "Set-Cookie: $cookie\n";
}

1;
