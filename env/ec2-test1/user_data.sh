#!/bin/bash
# Amazon Linux 2023: install nginx and serve a page showing the instance ID.
# NOTE: AWS Emulator does not boot a guest OS, so this only runs on real AWS.
set -euxo pipefail

dnf install -y nginx

TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
INSTANCE_ID=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

cat > /usr/share/nginx/html/index.html <<EOF
<!doctype html>
<html><body>
<h1>Hello from nginx on EC2</h1>
<p>instance: ${INSTANCE_ID}</p>
</body></html>
EOF

systemctl enable --now nginx
