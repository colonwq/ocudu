#!/usr/bin/env python3

import click
import ipaddress
import subprocess
import sys

try:
    import iptc
except ImportError:
    iptc = None

from pyroute2 import IPRoute
from pyroute2.netlink import NetlinkError


def handle_ip_string(ctx, param, value):
    try:
        ret = ipaddress.ip_network(value)
        return ret
    except ValueError:
        raise click.BadParameter(f'{value} is not a valid IP range.')


def _iptables_add_masquerade(if_name, ip_range):
    """Return True if the rule was added, False otherwise."""
    if iptc is None:
        return False
    try:
        chain = iptc.Chain(iptc.Table(iptc.Table.NAT), "POSTROUTING")
        rule = iptc.Rule()
        rule.src = ip_range
        rule.out_interface = if_name
        target = iptc.Target(rule, "MASQUERADE")
        rule.target = target
        chain.insert_rule(rule)
        return True
    except Exception:
        return False


def _iptables_allow_all(if_name):
    """Return True if the rule was added, False otherwise."""
    if iptc is None:
        return False
    try:
        chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), "INPUT")
        rule = iptc.Rule()
        rule.in_interface = if_name
        target = iptc.Target(rule, "ACCEPT")
        rule.target = target
        chain.insert_rule(rule)
        return True
    except Exception:
        return False


def _firewall_cmd_add_masquerade(ip_range):
    """Return True if the rule was added, False otherwise."""
    try:
        r = subprocess.run(
            [
                "firewall-cmd",
                "--permanent",
                "--add-rich-rule",
                f'rule family=ipv4 source address={ip_range} masquerade',
            ],
            capture_output=True,
            timeout=10,
        )
        if r.returncode != 0:
            return False
        r = subprocess.run(["firewall-cmd", "--reload"], capture_output=True, timeout=10)
        return r.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
        return False


def _firewall_cmd_allow_interface(if_name):
    """Return True if the rule was added, False otherwise."""
    try:
        r = subprocess.run(
            [
                "firewall-cmd",
                "--permanent",
                "--add-rich-rule",
                f'rule family=ipv4 interface name={if_name} accept',
            ],
            capture_output=True,
            timeout=10,
        )
        if r.returncode != 0:
            return False
        r = subprocess.run(["firewall-cmd", "--reload"], capture_output=True, timeout=10)
        return r.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
        return False


def setup_firewall_rules(if_name, ip_range_str):
    """Try iptables first, then firewall-cmd. Return (masquerade_ok, allow_ok)."""
    masq_ok = _iptables_add_masquerade(if_name, ip_range_str)
    if not masq_ok:
        masq_ok = _firewall_cmd_add_masquerade(ip_range_str)

    allow_ok = _iptables_allow_all(if_name)
    if not allow_ok:
        allow_ok = _firewall_cmd_allow_interface(if_name)

    if not masq_ok or not allow_ok:
        print(
            "CRITICAL: Could not add firewall rules (tried iptables and firewall-cmd). "
            "NAT/forwarding for the TUN interface may not work; TUN and routing are still set up.",
            file=sys.stderr,
        )
    return masq_ok, allow_ok


@click.command()
@click.option("--if_name", default="ogstun", help="TUN interface name.")
@click.option("--ip_range", default='10.45.0.0/24', callback=handle_ip_string,
              help="IP range of the TUN interface.")
def main(if_name, ip_range):

    for subnet in range(0,256):
        # Get the first IP address in the IP range and netmask prefix length
        first_ip_addr = next(ip_range.hosts(), None) + (subnet * 256)
        if not first_ip_addr:
            raise ValueError('Invalid IP range.')
        else:
            first_ip_addr = first_ip_addr.exploded

        ip_netmask = ip_range.prefixlen

        ipr = IPRoute()
        # create the tun interface
        ipr.link('add', ifname=if_name, kind='tuntap', mode='tun')
        # lookup the index
        dev = ipr.link_lookup(ifname=if_name)[0]
        # bring it down
        ipr.link('set', index=dev, state='down')
        # add primary IP address
        ipr.addr('add', index=dev, address=first_ip_addr, mask=ip_netmask)
        # bring it up
        ipr.link('set', index=dev, state='up')

        try:
            ipr.route('add', dst=ip_range.with_prefixlen, gateway=first_ip_addr)
        except NetlinkError:
            pass

        # Setup firewall once (same rules apply for all subnets): try iptables, then firewall-cmd
        if subnet == 0:
            setup_firewall_rules(if_name, ip_range.with_prefixlen)


if __name__ == "__main__":
    main()