#!/bin/bash

# ติดตั้ง CKAN บน Ubuntu 22.04 LTS CKAN 2.10.5 และ CKAN Extensions ต่างๆ 

# ลบไฟล์และโฟลเดอร์ที่เกี่ยวข้องกับ CKAN ถ้ามีการติดตั้งอยู่ก่อนแล้ว
echo " ################################################################################################################################################################################################"
echo "ลบไฟล์และโฟลเดอร์ที่เกี่ยวข้องกับ CKAN ที่มีอยู่..."
echo " ################################################################################################################################################################################################"
sudo systemctl stop ckan || true
sudo rm -rf /usr/lib/ckan/default
sudo rm -rf /etc/ckan
sudo rm -rf /var/lib/ckan
sudo rm -rf /var/log/ckan

# ลบไฟล์ nginx ที่เกี่ยวข้องกับ CKAN
sudo rm -f /etc/nginx/sites-enabled/ckan
sudo rm -f /etc/nginx/sites-available/ckan
sudo systemctl restart nginx

# ถอนการติดตั้งแพ็กเกจที่เกี่ยวข้อง
echo " ################################################################################################################################################################################################"
echo "ถอนการติดตั้งแพ็กเกจซอฟต์แวร์ที่เกี่ยวข้อง..."
echo " ################################################################################################################################################################################################"
sudo apt remove --purge -y python3-dev libpq-dev python3-pip python3-venv git-core redis-server nginx curl lsof postgresql openjdk-11-jdk
sudo apt autoremove -y
sudo apt clean

# ลบฐานข้อมูล PostgreSQL และผู้ใช้ที่เกี่ยวข้องกับ CKAN
echo " ################################################################################################################################################################################################"
echo "ลบฐานข้อมูล PostgreSQL และผู้ใช้ที่เกี่ยวข้องกับ CKAN..."
echo " ################################################################################################################################################################################################"
sudo -u postgres psql -c "DROP DATABASE IF EXISTS ckan_default;"
sudo -u postgres psql -c "DROP USER IF EXISTS ckan_default;"

# ลบ Solr ที่เกี่ยวข้องกับ CKAN
echo " ################################################################################################################################################################################################"
echo "ลบ Solr ที่เกี่ยวข้องกับ CKAN..."
echo " ################################################################################################################################################################################################"
sudo service solr stop
sudo rm -rf /opt/solr
sudo rm -rf /var/solr

# อัปเดตระบบและติดตั้งซอฟต์แวร์ที่จำเป็น
echo " ################################################################################################################################################################################################"
echo "อัปเดตระบบและติดตั้งซอฟต์แวร์ที่จำเป็น..."
echo " ################################################################################################################################################################################################"
sudo apt update
sudo apt upgrade -y
sudo apt install -y python3-dev libpq-dev python3-pip python3-venv git-core redis-server nginx curl lsof postgresql openjdk-11-jdk supervisor

# สร้าง virtual environment สำหรับ CKAN
echo " ################################################################################################################################################################################################"
echo "สร้าง virtual environment สำหรับ CKAN..."
echo " ################################################################################################################################################################################################"
sudo mkdir -p /usr/lib/ckan/default
sudo chown $USER /usr/lib/ckan/default
python3 -m venv /usr/lib/ckan/default
source /usr/lib/ckan/default/bin/activate

# ติดตั้ง CKAN และ Dependencies
echo " ################################################################################################################################################################################################"
echo "ติดตั้ง CKAN และ Dependencies..."
echo " ################################################################################################################################################################################################"
pip install --upgrade pip
pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.10.5#egg=ckan[requirements]'

# ออกจาก virtual environment
echo " ################################################################################################################################################################################################"
echo "ออกจาก virtual environment..."
echo " ################################################################################################################################################################################################"
deactivate
source /usr/lib/ckan/default/bin/activate

# ตั้งค่า PostgreSQL
echo " ################################################################################################################################################################################################"
echo "ตั้งค่า PostgreSQL..."
echo " ################################################################################################################################################################################################"
sudo -u postgres psql -c "CREATE USER ckan_default WITH PASSWORD 'your_password';"
sudo -u postgres psql -c "CREATE DATABASE ckan_default OWNER ckan_default ENCODING 'UTF8';"



# ปรับแต่ง PostgreSQL
echo " ################################################################################################################################################################################################"
echo "ปรับแต่ง PostgreSQL..."
echo " ################################################################################################################################################################################################"
sudo -u postgres psql -c "ALTER SYSTEM SET shared_buffers = '1GB';"
sudo -u postgres psql -c "ALTER SYSTEM SET work_mem = '128MB';"
sudo -u postgres psql -c "ALTER SYSTEM SET maintenance_work_mem = '256MB';"
sudo -u postgres psql -c "ALTER SYSTEM SET effective_cache_size = '3GB';"
sudo -u postgres psql -c "ALTER SYSTEM SET max_connections = '200';"
sudo -u postgres psql -c "ALTER SYSTEM SET wal_buffers = '16MB';"
sudo -u postgres psql -c "ALTER SYSTEM SET checkpoint_completion_target = '0.9';"
sudo -u postgres psql -c "ALTER SYSTEM SET random_page_cost = '1.1';"
sudo -u postgres psql -c "ALTER SYSTEM SET effective_io_concurrency = '200';"
sudo -u postgres psql -c "ALTER SYSTEM SET autovacuum = 'on';"
sudo systemctl restart postgresql

# ตั้งค่า CKAN
echo " ################################################################################################################################################################################################"
echo "ตั้งค่า CKAN..."
echo " ################################################################################################################################################################################################"
sudo mkdir -p /etc/ckan/default
sudo chown -R $USER /etc/ckan/
ckan generate config /etc/ckan/default/ckan.ini

# แก้ไขไฟล์ ckan.ini
echo " ################################################################################################################################################################################################"
echo "แก้ไขไฟล์ ckan.ini..."
echo " ################################################################################################################################################################################################"
sudo sed -i 's|sqlalchemy.url = .*|sqlalchemy.url = postgresql://ckan_default:your_password@localhost/ckan_default|' /etc/ckan/default/ckan.ini
sudo sed -i 's|ckan.site_url = .*|ckan.site_url = http://ckanteang.io|' /etc/ckan/default/ckan.ini

# ติดตั้งและตั้งค่า Solr
echo " ################################################################################################################################################################################################"
echo "ติดตั้งและตั้งค่า Solr..."
echo " ################################################################################################################################################################################################"
wget -4 https://downloads.apache.org/solr/solr/9.7.0/solr-9.7.0.tgz
tar xzf solr-9.7.0.tgz solr-9.7.0/bin/install_solr_service.sh --strip-components=2
sudo bash ./install_solr_service.sh solr-9.7.0.tgz
sudo -u solr /opt/solr/bin/solr create -c ckan
sudo -u solr wget -4 -O /var/solr/data/ckan/conf/managed-schema https://raw.githubusercontent.com/ckan/ckan/dev-v2.10/ckan/config/solr/schema.xml
sudo service solr restart

# แก้ไขไฟล์ ckan.ini สำหรับ Solr
echo " ################################################################################################################################################################################################"
echo "แก้ไขไฟล์ ckan.ini สำหรับ Solr..."
echo " ################################################################################################################################################################################################"
sudo sed -i 's|solr_url = .*|solr_url = http://127.0.0.1:8983/solr/ckan|' /etc/ckan/default/ckan.ini

# เริ่มต้นฐานข้อมูล CKAN
echo " ################################################################################################################################################################################################"
echo "เริ่มต้นฐานข้อมูล CKAN..."
echo " ################################################################################################################################################################################################"
cd /usr/lib/ckan/default/src/ckan
ckan -c /etc/ckan/default/ckan.ini db init

# ตั้งค่า Nginx
echo " ################################################################################################################################################################################################"
echo "ตั้งค่า Nginx..."
echo " ################################################################################################################################################################################################"
sudo tee /etc/nginx/sites-available/ckan > /dev/null <<EOF
server {
    listen 80;
    server_name ckanteang.io;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/ckan /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

sudo mkdir -p /var/lib/ckan
sudo chown -R $USER /var/lib/ckan

# ติดตั้ง Gunicorn และตั้งค่า CKAN เป็น Systemd Service
echo " ################################################################################################################################################################################################"
echo "ติดตั้ง Gunicorn และตั้งค่า CKAN เป็น Systemd Service..."
echo " ################################################################################################################################################################################################"
source /usr/lib/ckan/default/bin/activate
pip install gunicorn

sudo chown -R www-data:www-data /usr/lib/ckan/default
sudo chown -R www-data:www-data /etc/ckan
sudo chown -R www-data:www-data /var/lib/ckan
sudo chmod -R 644 /etc/ckan/default/ckan.ini
sudo chown -R www-data:www-data /etc/ckan

sudo chown -R www-data:www-data /var/lib/ckan
sudo chmod -R 755 /var/lib/ckan

sudo tee /etc/systemd/system/ckan.service > /dev/null <<EOF
[Unit]
Description=CKAN
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/usr/lib/ckan/default/src/ckan
Environment="CKAN_INI=/etc/ckan/default/ckan.ini"
ExecStart=/usr/lib/ckan/default/bin/gunicorn --workers 4 --bind 127.0.0.1:5000 "wsgi:application"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl restart ckan
sudo systemctl enable ckan
sudo systemctl start ckan
sudo systemctl status ckan

# การตั้งค่าสิทธิ์ไฟล์ config
echo " ################################################################################################################################################################################################"
echo "ตั้งค่าสิทธิ์ไฟล์ config..."
sudo chown -R www-data:www-data /etc/ckan
sudo chmod -R 644 /etc/ckan/default/ckan.ini
echo " ################################################################################################################################################################################################"


# ติดตั้งและตั้งค่า PostGIS บน PostgreSQL
echo " ################################################################################################################################################################################################"
echo "ติดตั้งและตั้งค่า PostGIS บน PostgreSQL..."
echo " ################################################################################################################################################################################################"
sudo apt install -y postgresql-14-postgis-3 postgresql-14-postgis-3-scripts
sudo -u postgres psql -d ckan_default -c "CREATE EXTENSION postgis;"
sudo -u postgres psql -d ckan_default -c "CREATE EXTENSION postgis_topology;"
sudo -u postgres psql -d ckan_default -c "CREATE EXTENSION postgis_raster;"
sudo -u postgres psql -d ckan_default -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ckan_default;"
sudo -u postgres psql -d ckan_default -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ckan_default;"



# ติดตั้ง Redis และ RQ
echo "ติดตั้ง Redis และ RQ..."
pip install redis rq

# ตั้งค่า Supervisor สำหรับ RQ Worker
sudo tee /etc/supervisor/conf.d/ckan-worker.conf > /dev/null <<EOF
[program:ckan-worker]
command=/usr/lib/ckan/default/bin/rq worker
autostart=true
autorestart=true
stderr_logfile=/var/log/ckan-worker.err.log
stdout_logfile=/var/log/ckan-worker.out.log
EOF


sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start ckan-worker


# การตั้งค่าสิทธิ์ไฟล์ config
sudo chown -R www-data:www-data /etc/ckan
sudo chmod -R 644 /etc/ckan/default/ckan.ini


# รีสตาร์ทบริการ CKAN
echo " ################################################################################################################################################################################################"
echo "รีสตาร์ทบริการ CKAN..."
echo " ################################################################################################################################################################################################"
sudo systemctl restart ckan

# แสดงข้อความสำเร็จ
echo "การติดตั้ง CKAN เสร็จสิ้น!"
