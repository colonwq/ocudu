#!/usr/bin/env python3

import click
import ipaddress
import subprocess
import sys

try:
    import iptc
except (ImportError, AttributeError, OSError, Exception):
    # iptc may be installed but fail to load (e.g. libiptc missing/incompatible in container)
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
    # print("_iptables_add_masquerade function being called", file=sys.stderr)
    if iptc is None:
        print("_iptables_add_masquerade: iptc module not available", file=sys.stderr)
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
    except Exception as e:
        print(f"_iptables_add_masquerade failed: {e}", file=sys.stderr)
        return False


def _iptables_allow_all(if_name):
    """Return True if the rule was added, False otherwise."""
    # print("_iptables_allow_all function being called", file=sys.stderr)
    if iptc is None:
        print("_iptables_allow_all: iptc module not available", file=sys.stderr)
        return False
    try:
        chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), "INPUT")
        rule = iptc.Rule()
        rule.in_interface = if_name
        target = iptc.Target(rule, "ACCEPT")
        rule.target = target
        chain.insert_rule(rule)
        return True
    except Exception as e:
        print(f"_iptables_allow_all failed: {e}", file=sys.stderr)
        return False


def _iptables_cmd_add_masquerade(if_name, ip_range_str):
    """Run iptables binary (e.g. iptables-nft on Ubuntu). Return True if rule added."""
    # print("_iptables_cmd_add_masquerade function being called", file=sys.stderr)
    try:
        r = subprocess.run(
            [
                "iptables",
                "-t", "nat",
                "-A", "POSTROUTING",
                "-s", ip_range_str,
                "-o", if_name,
                "-j", "MASQUERADE",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode != 0:
            if r.stderr:
                print(r.stderr, file=sys.stderr)
            return False
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception) as e:
        print(f"_iptables_cmd_add_masquerade failed: {e}", file=sys.stderr)
        return False


def _iptables_cmd_allow_all(if_name):
    """Run iptables binary. Return True if rule added."""
    # print("_iptables_cmd_allow_all function being called", file=sys.stderr)
    try:
        r = subprocess.run(
            [
                "iptables",
                "-A", "INPUT",
                "-i", if_name,
                "-j", "ACCEPT",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode != 0:
            if r.stderr:
                print(r.stderr, file=sys.stderr)
            return False
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception) as e:
        print(f"_iptables_cmd_allow_all failed: {e}", file=sys.stderr)
        return False


def _nft_add_masquerade(if_name, ip_range_str):
    """Add masquerade rule via nftables (Ubuntu 24.04 default). Return True if added."""
    # print("_nft_add_masquerade function being called", file=sys.stderr)
    try:
        # Ensure table and chain exist (ignore errors if already present)
        subprocess.run(
            ["nft", "add", "table", "ip", "nat"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        subprocess.run(
            [
                "nft", "add", "chain", "ip", "nat", "postrouting",
                "{ type nat hook postrouting priority 100 ; }",
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        # nft add rule needs the chain to exist; some systems have it via iptables-nft
        r = subprocess.run(
            [
                "nft", "add", "rule", "ip", "nat", "postrouting",
                "oifname", if_name, "ip", "saddr", ip_range_str, "masquerade",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode != 0:
            if r.stderr:
                print(r.stderr, file=sys.stderr)
            return False
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception) as e:
        print(f"_nft_add_masquerade failed: {e}", file=sys.stderr)
        return False


def _nft_allow_interface(if_name):
    """Add accept rule for interface via nftables. Return True if added."""
    # print("_nft_allow_interface function being called", file=sys.stderr)
    try:
        subprocess.run(
            ["nft", "add", "table", "ip", "filter"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        subprocess.run(
            [
                "nft", "add", "chain", "ip", "filter", "input",
                "{ type filter hook input priority 0 ; }",
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        r = subprocess.run(
            [
                "nft", "add", "rule", "ip", "filter", "input",
                "iifname", if_name, "accept",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode != 0:
            if r.stderr:
                print(r.stderr, file=sys.stderr)
            return False
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception) as e:
        print(f"_nft_allow_interface failed: {e}", file=sys.stderr)
        return False


def _firewall_cmd_add_masquerade(ip_range):
    """Return True if the rule was added, False otherwise."""
    # print("_firewall_cmd_add_masquerade function being called", file=sys.stderr)
    try:
        r = subprocess.run(
            [
                "firewall-cmd",
                "--permanent",
                "--add-rich-rule",
                f'rule family=ipv4 source address={ip_range} masquerade',
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode != 0:
            if r.stdout:
                print(r.stdout, file=sys.stderr)
            if r.stderr:
                print(r.stderr, file=sys.stderr)
            return False
        r = subprocess.run(["firewall-cmd", "--reload"], capture_output=True, text=True, timeout=10)
        if r.returncode != 0:
            if r.stdout:
                print(r.stdout, file=sys.stderr)
            if r.stderr:
                print(r.stderr, file=sys.stderr)
            return False
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception) as e:
        print(f"_firewall_cmd_add_masquerade failed: {e}", file=sys.stderr)
        return False


def _firewall_cmd_allow_interface(if_name):
    """Return True if the rule was added, False otherwise."""
    # print("_firewall_cmd_allow_interface function being called", file=sys.stderr)
    try:
        r = subprocess.run(
            [
                "firewall-cmd",
                "--permanent",
                "--add-rich-rule",
                f'rule family=ipv4 interface name={if_name} accept',
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode != 0:
            if r.stdout:
                print(r.stdout, file=sys.stderr)
            if r.stderr:
                print(r.stderr, file=sys.stderr)
            return False
        r = subprocess.run(["firewall-cmd", "--reload"], capture_output=True, text=True, timeout=10)
        if r.returncode != 0:
            if r.stdout:
                print(r.stdout, file=sys.stderr)
            if r.stderr:
                print(r.stderr, file=sys.stderr)
            return False
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception) as e:
        print(f"_firewall_cmd_allow_interface failed: {e}", file=sys.stderr)
        return False


def setup_firewall_rules(if_name, ip_range_str):
    """Try iptables (iptc), then iptables CLI, then nftables, then firewall-cmd. Return (masquerade_ok, allow_ok)."""
    masq_ok = _iptables_add_masquerade(if_name, ip_range_str)
    if not masq_ok:
        masq_ok = _iptables_cmd_add_masquerade(if_name, ip_range_str)
    if not masq_ok:
        masq_ok = _nft_add_masquerade(if_name, ip_range_str)
    if not masq_ok:
        masq_ok = _firewall_cmd_add_masquerade(ip_range_str)

    allow_ok = _iptables_allow_all(if_name)
    if not allow_ok:
        allow_ok = _iptables_cmd_allow_all(if_name)
    if not allow_ok:
        allow_ok = _nft_allow_interface(if_name)
    if not allow_ok:
        allow_ok = _firewall_cmd_allow_interface(if_name)

    if not masq_ok or not allow_ok:
        print(
            "CRITICAL: Could not add firewall rules (tried iptables, iptables-cmd, nftables, firewall-cmd). "
            "NAT/forwarding for the TUN interface may not work; TUN and routing are still set up.",
            file=sys.stderr,
        )
        print(f"  if_name={if_name!r} ip_range_str={ip_range_str!r}", file=sys.stderr)
    return masq_ok, allow_ok


@click.command()
@click.option("--if_name", default="ogstun", help="TUN interface name.")
@click.option("--ip_range", default='10.45.0.0/24', callback=handle_ip_string,
              help="IP range of the TUN interface.")
def main(if_name, ip_range):

    for subnet in range(0, 256):
        if subnet == 0:
            hosts = list(ip_range.hosts())
            print(f"ip_range={ip_range!r} ip_range.hosts()={hosts!r} subnet={subnet}", file=sys.stderr)
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