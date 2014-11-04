# Roku::ECP
# Package implementing Roku External Control Guide:
# http://sdkdocs.roku.com/display/sdkdoc/External+Control+Guide
package Roku::ECP;
use Data::Dumper;	# For debugging
use LWP::UserAgent;

our $VERSION = "0.0.1";
our $USER_AGENT = __PACKAGE__ . "/" . $VERSION;
		# User agent, for HTTP requests.

=head1 NAME

Roku::ECP - External Control Protocol for Roku

=head1 SYNOPSIS

  use Roku::ECP;

  my $r = new Roku::ECP
	hostname => "my-settop-box.dom.ain";

  my @apps = $r->apps();

  my $icon = $r->geticonbyid("12345");
  my $icon = $r->geticonbyid("12345");

=head1 DESCRIPTION

Roku::ECP implements the Roku External Control Guide, which permits
callers to query and control a Roku over the network.

=cut

# XXX - Known keys:
# Lit_* (replace "*" with a letter, e.g., send an "r" with "Lit_r")
use constant {
	KEY_Home	=> "home",
	KEY_Rev		=> "rev",
	KEY_Fwd		=> "fwd",
	KEY_Play	=> "play",
	KEY_Select	=> "select",
	KEY_Left	=> "left",
	KEY_Right	=> "right",
	KEY_Down	=> "down",
	KEY_Up		=> "up",
	KEY_Back	=> "back",
	KEY_InstantReplay	=> "instantreplay",
	KEY_Info	=> "info",
	KEY_Backspace	=> "backspace",
	KEY_Search	=> "search",
	KEY_Enter	=> "enter",
};
# Any UTF-8 character, URL-encoded.

=head1 METHODS
=cut

# XXX - SSDP to discover devices?

# Constructor: Encapsulate a Roku we want to talk to.
# Perhaps take multiple types of arguments:
#	name => hostname
#	addr => IPv4 (or in future IPv6) address
#	port => port number
# app2id: hash mapping app names to IDs.
# id2app?: hash mapping app IDs to names.

=head2 C<new>

  my $r = new Roku::ECP([I<var> => I<value>, ...])
  my $r = Roku::ECP->new

Create a new object with which to communicate with a Roku. For example:

  my $r = new Roku::ECP hostname => "my-settop-box.dom.ain";
  my $r = new Roku::ECP addr => "192.168.1.10",
	port => 1234;

Possible I<var>s:

=over 4

=item hostname

Name of the Roku.

=item addr

IP(v4) address of the Roku.

=item port

TCP port on which to communicate with the Roku.

=back

Only one of C<hostname> and C<addr> needs to be specified. If both are
given, the address takes precedence.

=cut
sub new
{
	my $class = shift;
	my %args = @_;
	my $retval = {
		port => 8060,
	};

	$retval->{"hostname"} = $args{"hostname"} if defined $args{"hostname"};
	$retval->{"addr"} = $args{"addr"} if defined $args{"addr"};
	if (!defined($args{"hostname"}) &&
	    !defined($args{"addr"}))
	{
		warn __PACKAGE__ . "::new: Must specify at least one of hostname or addr.";
		return undef;
	}

	$retval->{"port"} = $args{"port"} if defined $args{"port"};

	# Construct base URL for subsequent requests.
	$retval->{"url_base"} = "http://" .
		(defined($retval->{'addr'}) ? $retval->{'addr'} : $retval->{'hostname'}) .
		":$retval->{'port'}";

	# Construct a LWP::UserAgent to use for REST calls. Might as
	# well cache it if we're going to be making multiple calls.
	# There might be some benefit in caching the connection as
	# well.
	$retval->{'ua'} = new LWP::UserAgent
		agent => $USER_AGENT;

	bless $retval, $class;
	return $retval;
}

# XXX - Perhaps add a wrapper around the REST calls? We know the base
# URL from the constructor. The wrapper can take the path (e.g.,
# "/query/apps") and arguments, escape them properly and so on.

# _rest_request
sub _rest_request
{
	my $self = shift;
	my $method = shift;	# "GET" or "POST"
	my $path = shift;	# A URL path, like "/query/apps" or "/launch"
	my $result;

	# Call the right method for the request type.
	if ($method eq "GET")
	{
		$result = $self->{'ua'}->get($self->{'url_base'} . $path,
					     @_);
	} elsif ($method eq "POST") {
		$result = $self->{'ua'}->post($self->{'url_base'} . $path,
					      @_);
	} else {
		# XXX - Complain and die
	}
				       {});
	if ($result->code !~ /^2..$/)
	{
		return {
			status	=> undef,	# Unhappy
			error	=> $result->code(),
			message	=> $result->message(),
		};
	}

	return {
		status		=> 1,		# We're happy
		"Content-Type"	=> $result->header("Content-Type"),
		data		=> $result->decoded_content(),
	};
}

=head2 C<apps>

  my @apps = $r->apps();
	# $apps[0] ==
	# {
	#	id	=> '12345',	# Can include underscores
	#	type	=> 'appl',	# 'appl'|'menu'
	#	name	=> "Channel Name",
	#	version	=> '1.2.3',
	# }

Returns a list of ref-to-hash entries listing the channels installed
on the Roku.

=cut
sub apps
{
	my $self = shift;
	my @retval = ();
	my $result = $self->{'ua'}->get("$self->{'url_base'}/query/apps");
	if ($result->code !~ /^2..$/)
	{
		warn "Error: query/apps got status " . $result->code .
			": " . $result->message;
		return undef;
	}
	my $text = $result->decoded_content();

	# Yeah, ideally it'd be nice to have a full-fledged XML parser
	# but I can't be bothered until it actually becomes a problem.
	# We expect lines of the form
	#	<app id="1234" type="appl" version="1.2.3b">Some Channel</app>
	while ($text =~ m{
		<app \s+
		id=\"(\w+)\" \s+
		type=\"(\w+)\" \s+
		version=\"([^\"]+)\"
		>([^<]*)</app>
		}sgx)
	{
		my $app_id = $1;
		my $app_type = $2;
		my $app_version = $3;
		my $app_name = $4;

		push @retval, {
			id	=> $app_id,
			type	=> $app_type,
			version	=> $app_version,
			name	=> $app_name,
			};
	}

	$self->{'apps'} = [@retval];	# Cache a copy
	return @retval;
}

# XXX - Keydown
#	POST keydown/$key

# XXX - Ought to have two functions: &keydown(a,b,c,...), for named
# keys, and &keydown_str("hello world"), for strings.
#
# The former takes an arbitrary number of arguments; each one is the
# name of a known key (the KEY_* constants, above). &keydown sends
# each key in turn. That's because
#	&keydown(KEY_Home, KEY_Down, KEY_Right)
# is prettier than
#	&keydown(KEY_Home)
#	&keydown(KEY_Down)
#	&keydown(KEY_Right)
# Perhaps &keydown can also check whether an argument matches /^Lit_(.)$/
# and if so, send that character.
#
# &keydown_str, OTOH, takes one argument (okay, it can take several
# arguments, if there's any reason to do that), a string. It splits
# the string up into individual characters (not bytes; UTF-8
# characters) and sends a series of Lit_* characters (or whatever the
# best way is to send a series of characters).
sub keydown
{
	my $self = shift;
	my $key = shift;

	# XXX - It'd be nice to be able to send an arbitrary string,
	# even if it means splitting it up into umpteen separate HTTP
	# requests. But how do we distinguish one of the predefined
	# keys listed above, from an arbitrary string? (And, of
	# course, we want to be able to send the string "KEY_Home".)
	my $result = $self->{'ua'}->post("$self->{'url_base'}/keydown/" . $key,
				       {});
	if ($result->code !~ /^2..$/)
	{
		return {
			status	=> undef,	# Unhappy
			error	=> $result->code(),
			message	=> $result->message(),
		};
	}

	return {
		status		=> 1,		# We're happy
		"Content-Type"	=> $result->header("Content-Type"),
		data		=> $result->decoded_content(),
	};
}

# XXX - Keyup
#	POST keyup/$key
# XXX - Keypress
#	POST keypress/$key

# XXX - Launch
#	POST launch/$app_id[?$params...]

=head2 C<geticonbyid>

  my $icon = $r->geticonbyid("12345_67");
  print ICONFILE $icon->{data} if $icon->{status};

Fetches an app's icon. Most users will want to use C<geticonbyname>
instead.

Takes the ID of an app (usually a number, but sometimes not).
Returns an anonymous hash describing the app's icon:

=over 4

=item status

True if the icon was successfully fetched; false otherwise.

=item error

If C<status> is false, then C<error> gives the HTTP error code (e.g.,
404).

=item message

If C<status> is false, then C<message> gives the HTTP error message
(e.g., "not found").

=item Content-Type

The MIME type of the image. Usually C<image/jpeg> or C<image/png>.

=item data

The binary data of the icon.

=back

=cut
sub geticonbyid
{
	my $self = shift;
	my $app_id = shift;
	my $result = $self->{'ua'}->get("$self->{url_base}/query/icon/$app_id");
	if ($result->code !~ /^2..$/)
	{
		return {
			status	=> undef,	# Unhappy
			error	=> $result->code(),
			message	=> $result->message(),
		};
	}

	return {
		status		=> 1,		# We're happy
		"Content-Type"	=> $result->header("Content-Type"),
		data		=> $result->decoded_content(),
	};
}

=head2 C<geticonbyname>

  my $icon = $r->geticonbyid("My Roku Channel");
  print ICONFILE $icon->{data} if $icon->{status};

Fetches an app's icon.

Takes the name of an app (a string).

Returns an anonymous hash describing the app's icon, in the same
format as C<geticonbyid>.
=cut
sub geticonbyname
{
	my $self = shift;
	my $appname = shift;

	# Call 'apps' if necessary, to get a list of apps installed on
	# the Roku.
	if (!defined($self->{'apps'}))
	{
		# Fetch list of apps, since we don't have it yet
		$self->apps;
	}

	# Look up the app name in the id table
	my $id = undef;
	foreach my $app (@{$self->{'apps'}})
	{
		next unless $app->{'name'} eq $appname;
		$id = $app->{'id'};
		last;
	}
	return undef if !defined($id);	# Name not found

	# Call geticonbyid to do the hard work.
	return $self->geticonbyid($id);
}

# XXX - Input - Send custom events to a Brightscript app
#	POST /input?[$var=$val&...]

=head1 SEE ALSO

=over 4

=item External Control Guide

http://sdkdocs.roku.com/display/sdkdoc/External+Control+Guide

=back

=cut

1;
