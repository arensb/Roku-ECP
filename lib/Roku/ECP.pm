# Roku::ECP
# Package implementing Roku External Control Guide:
# http://sdkdocs.roku.com/display/sdkdoc/External+Control+Guide
package Roku::ECP;
use Data::Dumper;	# For debugging
use LWP::UserAgent;
use HTTP::Request;

=head1 NAME

Roku::ECP - External Control Protocol for Roku

=head1 SYNOPSIS

  use Roku::ECP;

  my $r = new Roku::ECP
	hostname => "my-settop-box.dom.ain";

  my $apps = $r->apps();

=head1 DESCRIPTION
XXX

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
print "base: [$retval->{'url_base'}]\n";

	bless $retval, $class;
	return $retval;
}

=head2 C<apps>

  my $hashref = $r->apps();

Returns a reference-to-hash listing the apps (channels) installed on
the Roku. The hash keys are the human-readable app names, and their
values are the internal IDs.

=cut
sub apps
{
	my $self = shift;
	my $ua = new LWP::UserAgent
		agent => "Roku::ECP/0.0.1 ";
		# XXX - Error-checking
	my $req = new HTTP::Request
		GET => $self->{'url_base'}."/query/apps"
		;
		# XXX - Error-checking
	my $result = $ua->request($req);
		# XXX - Error-checking
#print "apps: got ", Dumper($result);
	my $text = $result->decoded_content();
#print "apps: got ", $text;

	$self->{'appname2id'} = {};	# Map app name to its ID
#	$self->{'appid2name'} = {};	# Map app ID to its name

	# Yeah, ideally it'd be nice to have a full-fledged XML parser
	# but I can't be bothered until it actually becomes a problem.
	while ($text =~ m{
		<app \s+
		id=\"(\w+)\" \s+
		version=\"([^\"]+)\"
		>([^<]*)</app>
		}sgx)
	{
		my $app_id = $1;
		my $app_version = $2;
		my $app_name = $3;
#		print "name [$app_name] v [$app_version] => [$app_id]\n";
		$self->{'appname2id'}{$app_name} = $app_id;
#		$self->{'appid2name'}{$app_id} = $app_name;
	}

	return $self->{'appname2id'};
}

# XXX - Keydown
#	POST keydown/$key
# XXX - Keyup
#	POST keyup/$key
# XXX - Keypress
#	POST keypress/$key

# XXX - Launch
#	POST launch/$app_id[?$params...]

# XXX - Icon
#	GET query/icon/$app_id
sub geticonbyid
{
	my $self = shift;
	my $app_id = shift;

	my $ua = new LWP::UserAgent
		agent => "Roku::ECP/0.0.1 ";
	my $req = new HTTP::Request
		GET => $self->{'url_base'}."/query/apps"
		;
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
