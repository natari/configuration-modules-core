# ${license-info}
# ${developer-info}
# ${author-info}

# Note: all methods in this component are called in a
# $self->$method ($config) way, unless explicitly stated.

package NCM::Component::${project.artifactId};

use strict;
use warnings;
use NCM::Component;
use CAF::FileWriter;
use File::Path qw(mkpath);

use constant PATH => "/software/components/${project.artifactId}";
use constant CCMPATH => "/software/components/ccm";
use constant AIIDIR	=> "/etc/aii";
use constant AIISHELLFE	=> AIIDIR . "/aii-shellfe.conf";
use constant AIIDHCP	=> AIIDIR . "/aii-dhcp.conf";

our @ISA = qw (NCM::Component);
our $EC = LC::Exception::Context->new->will_store_all;

use constant CCM_IMPORTED_PROPERTIES => qw(ca_dir ca_file cert_file key_file);

sub Configure
{
    my ($self, $config) = @_;

    my $t = $config->getElement (PATH)->getTree;
    my $ccm_t = $config->getElement (CCMPATH)->getTree;


    # aii-shelffe configuration file
    
    my $fh = CAF::FileWriter->new(AIISHELLFE, log => $self);
    print $fh <<EOF;
# File generated by ncm-${project.artifactId}
# Do not edit
EOF

    foreach my $k (sort keys %{$t->{"aii-shellfe"}}) {
        my $v = $t->{"aii-shellfe"}->{$k};
        print $fh "$k = $v\n";
    }
    foreach my $k (CCM_IMPORTED_PROPERTIES) {
        if ( defined($ccm_t->{$k}) ) {
            print $fh "$k = $ccm_t->{$k}\n";
        }
    }

    $fh->close();


    # aii-dhcp configuration file
    
    $fh = CAF::FileWriter->new(AIIDHCP, log => $self);

    print $fh <<EOF;
# File generated by ncm-${project.artifactId}
# Do not edit
EOF

    foreach my $k (sort keys %{$t->{"aii-dhcp"}}) {
        my $v = $t->{"aii-dhcp"}->{$k};
        print $fh "$k = $v\n";
    }
    $fh->close();

    return 1;
}

1;
