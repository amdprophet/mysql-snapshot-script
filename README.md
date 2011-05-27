# What it does

This script can be used to backup MySQL databases that are stored on an EBS volume using XFS.

# Requirements

* xfsprogs
* mysql
* ruby
* rubygems
** mysql
** open4
** fog
** active_support

# Configuration

Open the script in your favourite editor and fill out the following fields

```ruby
# Amazon AWS Configuration
AWS_ACCESS_KEY_ID = ''
AWS_SECRET_ACCESS_KEY = ''
AWS_VOLUME = '' # EBS volume to make snapshots of

# MySQL Configuration
MYSQL_HOST = ''
MYSQL_USERNAME = ''
MYSQL_PASSWORD = ''
```

Then simply store the script in /etc/cron.hourly and you're done!