use strict;
package Web::Authenticate::User::Storage::Handler::SQL;
use Mouse;
use Carp;
use DBIx::Raw;
use Web::Authenticate::Digest;
use Web::Authenticate::User;
use Ref::Util qw/is_hashref/;
#ABSTRACT: Implementation of Web::Authenticate::User::Storage::Handler::Role that can be used with MySQL or SQLite.

with 'Web::Authenticate::User::Storage::Handler::Role';

=head1 DESCRIPTION

This L<Web::Authenticate::User::Storage::Handler::Role> is meant to be used with a very specific table structure:

    CREATE TABLE users (
    	id INTEGER PRIMARY KEY AUTO_INCREMENT,
        username VARCHAR(255) NOT NULL UNIQUE,
        password TEXT NOT NULL
    );

Other columns can exists, and the names of the table and column can change. But at least these columns must exist
in order for this storage handler to work properly. Also, the primary key does not have to be an integer, and could
even be the username.

=cut

=method users_table

Sets the name of the users table that will be used when querying the database. Default is 'users'.

=cut

has users_table => (
    isa => 'Str',
    is => 'ro',
    required => 1,
    default => 'users',
);

=method id_field

Sets the name of the id field that will be used when querying the database. Default is 'id'.

=cut

has id_field => (
    isa => 'Str',
    is => 'ro',
    required => 1,
    default => 'id',
);

=method username_field

Sets the name of the username field that will be used when querying the database. Default is 'username'.

=cut

has username_field => (
    isa => 'Str',
    is => 'ro',
    required => 1,
    default => 'username',
);

=method password_field

Sets the name of the password field that will be used when querying the database. Default is 'password'.

=cut

has password_field => (
    isa => 'Str',
    is => 'ro',
    required => 1,
    default => 'password',
);

=method digest

Sets the L<Web::Authenticate::Digest::Role> that is used. Default is L<Web::Authenticate::Digest>.

=cut

has digest => (
    does => 'Web::Authenticate::Digest::Role',
    is => 'ro',
    required => 1,
    default => sub { Web::Authenticate::Digest->new },
);

=method dbix_raw

Sets the L<DBIx::Raw> object that will be used to query the database. This is required with no default.

=cut

has dbix_raw => (
    isa => 'DBIx::Raw',
    is => 'ro',
    required => 1,
);

=method columns

The columns to select. At a minimum, L</id_field> and L</password_field> will always be selected.

    $user_storage_handler->columns([qw/name age/]);

Default is an empty array ref.

=cut

has columns => (
    isa => 'ArrayRef',
    is => 'ro',
    required => 1,
    default => sub { [] },
);

=method load_user

Accepts the username and password for a user, and returns a L<Web::Authenticate::User> if the password is correct and the user exists.
Otherwise, undef is returned. Any additional L</columns> will be stored in L<Web::Authenticate::User/row>. However, the password will be
deleted from the row before it is stored.

    my $user = $user_storage_handler->load_user($username, $password);

=cut

sub load_user {
    my ($self, $username, $password) = @_;
    croak "must provide username" unless $username;
    croak "must provide password" unless $password;

    my $users_table = $self->users_table;
    my $id_field = $self->id_field;
    my $username_field = $self->username_field;
    my $password_field = $self->password_field;

    my $selection = $self->_get_selection($id_field, $password_field);
    my $user = $self->dbix_raw->raw("SELECT $selection FROM $users_table WHERE $username_field = ?", $username);

    unless ($user->{$id_field} and $user->{$password_field} and 
        $self->digest->validate($user->{$password_field}, $password)) {
        carp "unable to load user";
        return;
    }

    delete $user->{$password_field};

    return Web::Authenticate::User->new(id => $user->{$id_field}, row => $user);
}

=method load_user_by_id

Loads a user by id.

    my $user = $user_storage_handler->load_user_by_id($user_id);

=cut

sub load_user_by_id {
    my ($self, $user_id) = @_;
    croak "must provide user_id" unless $user_id;

    my $users_table = $self->users_table;
    my $id_field = $self->id_field;
    my $username_field = $self->username_field;
    my $password_field = $self->password_field;

    my $selection = $self->_get_selection($id_field);
    my $user = $self->dbix_raw->raw("SELECT $selection FROM $users_table WHERE $id_field = ?", $user_id);

    unless ($user) {
        carp "unable to load user";
        return;
    }

    # if the only thing we selected was id, then we just got a scalar back
    unless (is_hashref($user)) {
        $user = {$id_field => $user};
    }

    return Web::Authenticate::User->new(id => $user->{$id_field}, row => $user);
}

=method store_user

Takes in username, password, and any additional values for columns in a hash and we create that user with their hashed password.
Returns a L<Web::Authenticate::User> with any values from L</columns> stored in L<Web::Authenticate::User/row>.

    my $user_values => {
        name => 'Fred',
        age => 34,
        insert_time => \'NOW()', # scalar ref for literal values. See DBIx::Raw
    };
    my $user = $user_storage_handler->store_user($username, $password, $user_vaules);

    # if you need no extra user values in the row
    my $user = $user_storage_handler->store_user($username, $password);

=cut

sub store_user {
    my ($self, $username, $password, $user_values) = @_;
    croak "must provide username" unless $username;
    croak "must provide password" unless $password;

    my $users_table = $self->users_table;
    my $id_field = $self->id_field;;
    my $username_field = $self->username_field;
    my $password_field = $self->password_field;

    $user_values //= {};
    $user_values->{$username_field} = $username;
    $user_values->{$password_field} = $self->digest->generate($password);;

    $self->dbix_raw->insert(href => $user_values, table => $users_table);

    # select columns user wants here instead except password_hash. Then pass into extra field
    my $selection = $self->_get_selection($id_field);
    my $user = $self->dbix_raw->raw("SELECT $selection FROM $users_table WHERE $username_field = ?", $username);

    unless ($user) {
        carp "unable to load user";
        return;
    }

    # if the only thing we selected was id, then we just got a scalar back
    unless (is_hashref($user)) {
        $user = {$id_field => $user};
    }

    return Web::Authenticate::User->new(id => $user->{$id_field}, row => $user);
}

sub _get_selection {
    my ($self, @columns) = @_;

    die "columns required" unless @columns;

    my $selection = join ',', @columns;

    if (@{$self->columns}) {
        $selection .= ',' . join ',', @{$self->columns}; 
    }

    return $selection;
}

1;
