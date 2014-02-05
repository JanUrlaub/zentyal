#!/usr/bin/perl -w
#
# Copyright (C) 2014 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use warnings;
use strict;

package EBox::HA::ClusterStatus::Test;

use base 'Test::Class';

use EBox::Global::TestStub;
use EBox::HA;
use EBox::Module::Config::TestStub;
use EBox::Test::RedisMock;
use Test::Deep;
use Test::Exception;
use Test::More;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub clusterStatus_use_ok : Test(startup => 1)
{
    use_ok('EBox::HA::ClusterStatus') or die;
}

sub setUpInstance : Test(setup)
{
    my ($self) = @_;
    my $redis = EBox::Test::RedisMock->new();
    my $ha = EBox::HA->_create(redis => $redis);
    $self->{xml} = "<?xml version='1.0'?>
        <crm_mon version='1.1.10'>
        <summary>
            <last_update time='Thu Jan 30 10:34:32 2014' />
            <last_change time='Thu Jan 30 10:33:45 2014' user='' client='cibadmin' origin='perra-vieja' />
            <stack type='corosync' />
            <current_dc present='true' version='1.1.10-42f2063' name='perra-vieja' id='1' with_quorum='true' />
            <nodes_configured number='3' expected_votes='unknown' />
            <resources_configured number='2' />
        </summary>
        <nodes>
            <node name='mega-cow' id='1' online='true' standby='false' standby_onfail='false' maintenance='false' pending='false' unclean='false' shutdown='false' expected_up='true' is_dc='true' resources_running='2' type='member' />
            <node name='mini-fox' id='2' online='true' standby='false' standby_onfail='false' maintenance='false' pending='false' unclean='false' shutdown='false' expected_up='true' is_dc='false' resources_running='0' type='member' />
            <node name='failed-doggie' id='3' online='false' standby='false' standby_onfail='false' maintenance='false' pending='false' unclean='false' shutdown='false' expected_up='true' is_dc='false' resources_running='0' type='member' />
        </nodes>
        <resources>
            <resource id='ClusterIP' resource_agent='ocf::heartbeat:IPaddr2' role='Started' active='true' orphaned='false' managed='true' failed='false' failure_ignored='false' nodes_running_on='1' >
            </resource>
            <resource id='ClusterIP2' resource_agent='ocf::heartbeat:IPaddr2' role='Started' active='true' orphaned='false' managed='true' failed='false' failure_ignored='false' nodes_running_on='1' >
            </resource>
        </resources>
        </crm_mon>";
    $self->{clusterStatus} = new EBox::HA::ClusterStatus($ha, $self->{xml});
}

sub test_isa_ok  : Test
{
    my ($self) = @_;
    isa_ok($self->{clusterStatus}, 'EBox::HA::ClusterStatus');
}

sub test_status_info : Test(6)
{
    my ($self) = @_;

    my $clusterStatus = $self->{clusterStatus};

    cmp_ok($clusterStatus->activeNode(), 'eq', 'mega-cow', 'Getting the active node');
    ok($clusterStatus->nodeOnline('mega-cow'), 'Testing an online node');
    ok(! $clusterStatus->nodeOnline('failed-doggie'), 'Testing an offline node');
    cmp_ok($clusterStatus->numberOfNodes(), '==', 3, 'Counting the nodes');
    cmp_ok($clusterStatus->numberOfResources(), '==', 2, 'Counting the resources');
    cmp_ok($clusterStatus->getDesignatedController(), 'eq', 'perra-vieja', 'Getting the DC');
}

sub test_status_summary : Test(7)
{
    my ($self) = @_;

    my $clusterStatus = $self->{clusterStatus};
    my %summary = $clusterStatus->getSummary();
    cmp_ok($summary{'number_of_nodes'}, '==', 3, 'Counting the nodes ( internal )');
    cmp_ok($summary{'number_of_resources'}, '==', 2, 'Counting the resources ( internal )');
    cmp_ok($summary{'last_update'}, 'eq', 'Thu Jan 30 10:34:32 2014', 'Cluster last update');
    cmp_ok($summary{'last_change'}, 'eq', 'Thu Jan 30 10:33:45 2014', 'Cluster last change');
    cmp_ok($summary{'last_change_origin'}, 'eq', 'perra-vieja', 'Node that made the last change');
    cmp_ok($summary{'stack_type'}, 'eq', 'corosync', 'Cluster message layer');
    cmp_ok($summary{'designated_controller_name'}, 'eq', 'perra-vieja', 'DC ( internal )');
}

sub test_status_search : Test(4)
{
    my ($self) = @_;

    my $clusterStatus = $self->{clusterStatus};

    my %node = %{ $clusterStatus->nodeByName('mega-cow') };
    cmp_ok($node{'name'}, 'eq', 'mega-cow', 'Searching by name');
    %node = %{ $clusterStatus->nodeByName('mini-fox') };
    cmp_ok($node{'name'}, 'eq', 'mini-fox', 'Searching by name (2)');

    %node = %{ $clusterStatus->nodeById(1) };
    cmp_ok($node{'name'}, 'eq', 'mega-cow', 'Searching by id');
    %node = %{ $clusterStatus->nodeById(2) };
    cmp_ok($node{'name'}, 'eq', 'mini-fox', 'Searching by id (2)');
}

sub test_status_print : Test(2)
{
    my ($self) = @_;

    my $clusterStatus = $self->{clusterStatus};
    ok($clusterStatus->getNodes(), 'Nodes retrieved');
    ok($clusterStatus->getResources(), 'Resources retrieved');

    use Data::Dumper;
    diag(Dumper($clusterStatus->getNodes()));
    diag(Dumper($clusterStatus->getResources()));
}

1;

END {
    EBox::HA::ClusterStatus::Test->runtests();
}
