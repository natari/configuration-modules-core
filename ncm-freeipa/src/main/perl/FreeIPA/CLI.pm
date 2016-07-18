#${PMpre} NCM::Component::FreeIPA::CLI${PMpost}

use parent qw(CAF::Application NCM::Component::freeipa CAF::Reporter CAF::Object Exporter);

our @EXPORT = qw(install);

use CAF::Object qw(SUCCESS);
use CAF::Process;

use Readonly;

Readonly::Array my @TIME_SERVICES => qw(ntpd chronyd ptpd ptpd2);
Readonly::Array my @NTPDATE_SYNC => qw(/usr/sbin/ntpdate -U ntp -b -v);

Readonly::Array my @IPA_INSTALL => qw(ipa-client-install --unattended --debug --noac);
Readonly::Array my @IPA_INSTALL_NOS => qw(sssd sudo sshd ssh ntp dns-sshfp nisdomain);


=pod

=head1 CLI FreeIPA

Module to use as CLI to FreeIPA

=head1 DESCRIPTION

Module to use as CLI to FreeIPA, e.g. when initialising on existing host
or during kickstart.

Runs with default debug level 5.

Example command (one line)

    PERL5LIB=/usr/lib/perl perl -MNCM::Component::FreeIPA::CLI -w -e install --
        --realm MY.REALM --primary primary.example.com --otp abcdef123456
        --domain example.com --short thishost

=head1 DEPENDENCIES

    Rpms:
        nss_ldap ipa-client ncm-freeipa
        nss-tools openssl
=cut

sub install
{

    # fix umask
    umask (022);

    # unbuffer STDOUT & STDERR
    autoflush STDOUT 1;
    autoflush STDERR 1;

    my $ec = 1; # Failure
    my $name = $0 || 'bootstrap';
    if (my $app = NCM::Component::FreeIPA::CLI->new($name, '--debug', 5, @ARGV)) {
        $app->info("CLI install started with name $name and args @ARGV");
        my $prim = $app->option('primary');
        my $realm = $app->option('realm');
        my $domain = $app->option('domain');

        if ($app->ipa_install($prim ,$realm, $app->option('otp'), $domain)) {
            if($app->minimal_component($app->option('short').".$domain", $prim, $realm)) {
                $app->info("install success");
                $ec = 0;
            } else {
                $app->error("minimal_component failed");
            };
        } else {
            $app->error("join_ipa failed");
        };

    } else {
        print "[ERROR] install failed to initialise NCM::Component::FreeIPA::CLI with name $name and args @ARGV\n";
    }


    exit($ec);
}



sub app_options {

    # these options complement the ones defined in CAF::Application
    push(my @array,

         { NAME    => 'primary=s',
           HELP    => 'primary IPA server' },

         { NAME    => 'realm=s',
           HELP    => 'kerberos realm' },

         { NAME    => 'otp=s',
           HELP    => 'one-time password' },

         { NAME    => 'domain=s',
           HELP    => 'domain name' },

         { NAME    => 'short=s',
           HELP    => 'short hostname (fqdn without domain)' },

         { NAME    => 'logfile=s',
           HELP    => 'Logfile',
           DEFAULT => '/var/log/ncm-freeipa-CLI.log' },
        );

    return(\@array);
}

sub _initialize {

    my $self = shift;

    # append to logfile, do not truncate
    $self->{'LOG_APPEND'} = 1;

    # add time stamp before every entry in log
    $self->{'LOG_TSTAMP'} = 1;

    # start initialization of CAF::Application
    unless ($self->SUPER::_initialize(@_)) {
        return;
    }

    # Set reporter log instance attributes for both CAF and Component
    $self->{log} = $self;
    $self->{LOGGER} = $self->{log};

    # start using log file (could be done later on instead)
    $self->set_report_logfile($self->{'LOG'});

    return(SUCCESS);
}


# Seems like ipa-client-install might want to sync time
# (even if --no-ntp is used)
# Prepare the time before running ipa-client-install
# Requires ntpdate and ntpd installed (can be removed again)
# This does not seem necessary anymore?
sub pre_time
{
    my ($self, $ntpserver) = @_;

    # Discover which time services were running
    $self->{post_time} = {
        start => [],
        stop => [],
    };

    foreach my $srv (@TIME_SERVICES) {
        # Check service status, stop them all if running
    }


    # Sync time if needed (using? ntpd -gq? sntpd? ntpdate?)
    my $sync_cmd = [@NTPDATE_SYNC, $ntpserver];

    # Start ntpd, so ipa-client install won't do it

    # Add ntpd to post_time stop if not in post_time start
}


sub post_time
{
    my ($self) = @_;

    foreach my $srv (@{$self->{post_time}->{stop}}) {
    }

    foreach my $srv (@{$self->{post_time}->{start}}) {
    }

}

# TODO: ipa-join is enough?
sub ipa_install
{
    my ($self, $primary, $realm, $otp, $domain, %opts) = @_;

    my $ec = SUCCESS;
    $self->debug(1, "begin ipa_install with primary $primary realm $realm");


    #$self->pre_time($opts{ntpserver});

    # It is ok to log this, the password is an OTP
    # TODO: set expiration window on password or cron job to reset password
    my $cmd = [
        @IPA_INSTALL,
        '--server', $primary,
        '--realm', $realm,
        '--password', $otp,
        '--domain', $domain,
        map {"--no-$_"} @IPA_INSTALL_NOS, # Nothing after this, will all be map'ped
        ];

    my $output = CAF::Process->new($cmd, log => $self)->output();
    if ($?) {
        $self->error("ipa-install failed (ec $?): $output");
        $ec = 0;
    } else {
        $self->info("ipa-install success: $output");
    }

    #$self->post_time();

    $self->debug(1, "end ipa_install with ec $ec");
    return $ec;
}

# Generate miminal client setup for quattor usage
# TODO: handle errors like ncm-ncd (i.e. logged error is failure).
sub minimal_component
{
    my ($self, $fqdn, $primary, $realm) = @_;

    $self->debug(1, "begin minimal_component with primary $primary realm $realm");

    # Set class variable
    $self->set_fqdn(fqdn => $fqdn);

    # No keytabs, use host keytab for ccm-fetch?
    # Retrieve the certificate from the host keytab
    my $quattor_cert = {
        owner => 'root',
        group => 'root',
        mode => 0400,
        key => '/etc/pki/tls/private/quattor.key',
        certmode => 0444,
        cert => '/etc/pki/tls/certs/quattor.pem',
    };

    my $tree = {
        primary => $primary,
        realm => $realm,
        certificates => {
            quattor => $quattor_cert,
        },
    };

    my $ec = $self->_configure($tree);

    $self->debug(1, "end minimal_component_install with ec $ec");

    return $ec;
}

1;
