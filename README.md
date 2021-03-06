# ncio - Puppet Node Classifier backup / restore

This project implements a small command line utility to backup and restore node
classification data.  The intended purpose is to backup node classification
groups on a Primary, monolithic PE master and restore the backup on a secondary
monolithic PE master.  The purpose is to keep node classification groups in sync
and ready in the event the secondary master needs to take over service from the
primary.


## Transformation

To achieve the goal of replicating node classification groups from one PE
monolithic master to a secondary monolithic master, certain values need to be
transformed.  For example, consider a primary named `master1.puppet.vm` and a
secondary named `master2.puppet.vm`  Both are monolithic masters.  When the
backup is taken on the primary, the hostname will be embedded in the data.  This
is problematic because it will cause mis-configuration errors when imported into
the secondary which has a different name.

To illustrate, consider the PuppetDB classification group:

    {
      "name": "PE PuppetDB",
      "rule": [
        "or",
        [
          "=",
          "name",
          "master1.puppet.vm"
        ]
      ],
      "classes": {
        "puppet_enterprise::profile::puppetdb": {
        }
      }
    }

Transformation from master1 to master2 is possible:

    export PATH="/opt/pupeptlabs/puppet/bin:$PATH"
    ncio --uri https://master1.puppet.vm:4433/classification-api/v1 backup \
     | ncio transform --hostname master1.puppet.vm:master2.puppet.vm \
     | ncio --uri https://master2.puppet.vm:4433/classification-api/v1 restore

This method of "replicating" node classification data has some caveats.  It's
only been tested on PE Monolithic masters.  The method assumes master1 and
master2 share the same Certificate Authority.  By default, only the default
`puppet_enterprise` classification groups are transformed.

Additional groups and classes may be processed by chaining transfomation
processes and getting creative with the use of the `--class-matcher` option.

## Installation

Install this tool on the same node running the node classification service:

    $ sudo /opt/puppetlabs/puppet/bin/gem install ncio
    Successfully installed ncio-0.1.0
    Parsing documentation for ncio-0.1.0
    Installing ri documentation for ncio-0.1.0
    Done installing documentation for ncio after 0 seconds
    1 gem installed

## Usage

Ncio will attempt to use the host certificate from
`/etc/puppetlabs/puppet/ssl/certs/$FQDN.pem` if it exists on the same node as
the Node Classifier.  If this certificate has sufficient access then no
configuration is necessary.  The default options will work to backup and restore
node classification data.

    sudo -H -u pe-puppet /opt/puppetlabs/puppet/bin/ncio backup > /var/tmp/backup.json
    I, [2016-06-28T19:25:55.507684 #2992]  INFO -- : Backup completed successfully!

If this file does not exist, ncio will need to use a different client
certificate.  It is recommended to use the same certificate used by the Puppet
Agent, which should be white-listed for node classification API access.  The
white-list of certificates is located at
`/etc/puppetlabs/console-services/rbac-certificate-whitelist`

    sudo -H -u pe-puppet /opt/puppetlabs/puppet/bin/ncio \
      --cert /etc/puppetlabs/puppet/ssl/certs/${HOSTNAME}.pem \
      --key  /etc/puppetlabs/puppet/ssl/private_keys/${HOSTNAME}.pem \
      backup > /var/tmp/backup.json
    I, [2016-06-28T19:28:48.236257 #3148]  INFO -- : Backup completed successfully!

## Logging

The status of backup and restore operations are logged to the syslog by default.
The `daemon` facility is used to ensure messages are written to files on a wide
variety of systems that log daemon messages by default.  A general exception
handler will log a backtrace in JSON format to help log processors and
notification systems like Splunk and Logstash.

Here's an example of a failed restore triggering the catch all handler:

    Jun 29 12:12:21 Jeff-McCune ncio[51474]: ERROR Restoring backup: {
      "error": "RuntimeError",
      "message": "Some random error",
      "backtrace": [
        "/Users/jeff/projects/puppet/ncio/lib/ncio/app.rb:94:in `restore_groups'",
        "/Users/jeff/projects/puppet/ncio/lib/ncio/app.rb:59:in `run'",
        "/Users/jeff/projects/puppet/ncio/exe/ncio:5:in `<top (required)>'"
      ]
    }

Log to the console using the `--no-syslog` command line option.

    ncio --no-syslog restore --file backup.json

The tool can only log to either syslog or the console at this time.  Multiple
log destinations are not currently supported.

## Retrying Connections

It can take some time for the `pe-console-services` service to come online.  In
an effort to make things are robust as possible consider using the
`--retry-connections` global option.  This allows ncio to retry API connections
while the service comes online.  This option has been added to address the
following use case:

    service start pe-console-services.service
    ncio --retry-connections backup

In this scenario ncio will retry API connections, eventually succeeding or
timing out.  Ideally the service will come online before the timeout expires.

## Replication

A simple way to replicate node classification data between a primary and a
secondary can be achieved with the following shell script.  Call this from cron
on a periodic basis:

```bash
#! /bin/bash
#
# This shell script is intended to be executed from cron on a periodic basis.
# The goal is to keep a Standby PE Monolithic master in sync with an active
# Primary.  Pass the FQDN of the primary as ARG 1 and the FQDN of the secondary
# as ARG 2
#
# In a DR situation when the secondary becomes active, block replication by
# touching the lockfile.  This will prevent any changes made to the standby from
# being clobbered as soon as the primary comes back online.
#
# Prior to re-enabling replication after a DR situation, replicate back to the
# primary by reversing the direction of this script.

set -euo pipefail

PRIMARY="$1"
STANDBY="$2"

SOURCE="https://${PRIMARY}:4433/classification-api/v1"
PATH="/opt/puppetlabs/puppet/bin:$PATH"
lockfile='/etc/ncio_do_not_replicate'

log() {
  logger -t ncio-replicate -p daemon.warn -s "$1"
}

if [[ -e "$lockfile" ]]; then
  log "WARN: Replication aborted, $lockfile exists!"
  exit 1
fi

ncio --uri "$SOURCE" --retry-connections backup \
  | ncio transform --hostname "${PRIMARY}:${STANDBY}" \
  | ncio --retry-connections restore
rval=$?

[[ $rval -eq 0 ]] && STATUS='OK' || STATUS='ERROR'
msg="INFO: Finished replicating puppet classification groups."
log "$msg STATUS=${STATUS} EXITCODE=${rval} (touch $lockfile to disable)"
exit $rval
```

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/jeffmccune/ncio.

## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).
