#!/usr/bin/env bash

set -e

# Set the environment varis.
sudo tee -a /home/ec2-user/.bash_profile << EOF
export APP_ENV=produdction
export APP_ROLE=api
EOF

# Update the server
yum -y update
yum -y upgrade
amazon-linux-extras install -y nginx1.12 php7.2
yum install autoconf-2.69-11.amzn2.noarch automake-1.13.4-3.1.amzn2.noarch -y

# Install AWS Agent
cd /tmp
wget https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install
sudo bash install
/etc/init.d/awsagent start

# Install CodeDeploy agent
yum install wget ruby -y
cd /home/ec2-user
wget https://aws-codedeploy-eu-west-1.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo service codedeploy-agent start
cd /tmp

# Install PHP extensions
yum install -y gd php-mbstring php-gd php-simplexml php-dom php-zip php-opcache

# configure Nginx
rm -Rf /var/www/html/public
mkdir -p /var/www/html/public
echo "Nginx ready" > /var/www/html/public/index.php
usermod -a -G nginx ec2-user
chown -R ec2-user:nginx /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
chkconfig nginx on
service nginx start

# Add in custom PHP and Nginx config
curl https://raw.githubusercontent.com/RoyalBoroughKingston/ck-scripts/master/api/www.conf | sudo tee /etc/php-fpm.d/www.conf
curl https://raw.githubusercontent.com/RoyalBoroughKingston/ck-scripts/master/api/default.conf | sudo tee /etc/nginx/conf.d/default.conf
curl https://raw.githubusercontent.com/RoyalBoroughKingston/ck-scripts/master/api/nginx.conf | sudo tee /etc/nginx/nginx.conf

# Restart the PHP and Nginx services
service php-fpm reload
service nginx reload

# Install packages
yum install -y git

# Install NPM
curl -sL https://rpm.nodesource.com/setup_8.x | sudo -E bash -
yum install nodejs -y --enablerepo=nodesource

# Install libpng-devl
yum install -y gcc make libpng-devel

# Install composer
cd ~
curl -sS https://getcomposer.org/installer | sudo php
mv composer.phar /usr/local/bin/composer
ln -s /usr/local/bin/composer /usr/bin/composer
export COMPOSER_HOME="$HOME/.config/composer/"

# Install AWS CloudWatch
wget https://s3.amazonaws.com/amazoncloudwatch-agent/linux/amd64/latest/AmazonCloudWatchAgent.zip
unzip AmazonCloudWatchAgent.zip
sudo ./install.sh
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/www/html/storage/logs/laravel.log",
                        "log_group_name": "laravel.log",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S",
                        "multi_line_start_pattern": "{timestamp_format}"
                    }
                ]
            }
        }
    },
    "metrics": {
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 30,
                "resources": [
                    "*"
                ],
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent",
                    "inodes_free"
                ],
                "metrics_collection_interval": 30,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 30,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 30
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 30
            }
        }
    }
}
EOF
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Update AWSCLI
cd /tmp
curl -O https://bootstrap.pypa.io/get-pip.py
python get-pip.py
pip install awscli --upgrade

echo "Boot script complete"
