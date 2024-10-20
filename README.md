ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

cat ~/.ssh/id_rsa.pub

sudo nano install_ckan.sh
sudo chmod +x install_ckan.sh
sudo ./install_ckan.sh
