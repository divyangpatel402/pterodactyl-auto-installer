#!/bin/bash

# ==============================================================================
# Pterodactyl & Reviactyl Auto Installer Script
# ==============================================================================

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "=========================================================="
echo "    Pterodactyl & Reviactyl Auto Setup Script"
echo "=========================================================="
echo "1. Install Pterodactyl Panel With Wings Auto Online"
echo "2. Uninstall Pterodactyl Panel & Wings"
echo "3. Install Reviactyl Panel (Must have Pterodactyl installed first)"
echo "=========================================================="
read -p "Enter your choice [1-3]: " choice

if [ "$choice" == "1" ]; then
    echo ""
    echo "Go to Cloudflare.com and Add vps ipv4 Ip and DNS only."
    read -p "Press [Enter] once you have done this to continue..."
    
    read -p "Enter your DNS subdomain (Panel FQDN, e.g., panel.yourdomain.com): " PANEL_FQDN
    read -p "Enter Email: " EMAIL
    read -p "Enter First Name: " FIRST_NAME
    read -p "Enter Last Name: " LAST_NAME

    echo "Installing Dependencies and Docker..."
    apt update -y && apt upgrade -y
    apt install -y curl wget tar unzip git jq software-properties-common apt-transport-https ca-certificates gnupg expect
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker

    echo "Installing Pterodactyl Panel (Using Community Installer)..."
    cat << 'EOF' > /tmp/ptero_panel.exp
#!/usr/bin/expect -f
set timeout -1
set FQDN [lindex $argv 0]
set EMAIL [lindex $argv 1]
set FNAME [lindex $argv 2]
set LNAME [lindex $argv 3]

spawn bash -c "bash <(curl -s https://pterodactyl-installer.se)"

expect "Input 0-6:"
send "0\r"

expect {
    "Are you sure you want to proceed?" {
        send "y\r"
        expect "Database name"
        send "\r"
    }
    "Database name" {
        send "\r"
    }
}

expect "Database username"
send "\r"

expect "randomly generated password"
send "\r"

expect "Select timezone"
send "UTC\r"

expect "configure Let's Encrypt and Pterodactyl:"
send "$EMAIL\r"

expect "Email address for the initial admin account:"
send "$EMAIL\r"

expect "Username for the initial admin account:"
send "admin\r"

expect "First name for the initial admin account:"
send "$FNAME\r"

expect "Last name for the initial admin account:"
send "$LNAME\r"

expect "Password for the initial admin account:"
send "AdminPass123!\r"

expect "FQDN of this panel"
send "$FQDN\r"

expect "configure UFW"
send "y\r"

expect "configure HTTPS using Let's Encrypt"
send "y\r"

expect {
    "I agree that this HTTPS request is performed" {
        send "y\r"
        expect "Proceed with installation"
        send "y\r"
    }
    "Proceed with installation" {
        send "y\r"
    }
}

expect {
    "Enable sending anonymous telemetry data?" {
        send "no\r"
        exp_continue
    }
    eof
}
EOF
    chmod +x /tmp/ptero_panel.exp
    /tmp/ptero_panel.exp "$PANEL_FQDN" "$EMAIL" "$FIRST_NAME" "$LAST_NAME"

    echo ""
    echo "what is your Node fqdn like ex same add New Subdomin DNS only on your Cloudfalre.com Ex node.yourdomin.site"
    read -p "Enter your Node FQDN: " NODE_FQDN

    echo "Installing Wings..."
    mkdir -p /etc/pterodactyl
    curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
    chmod u+x /usr/local/bin/wings

    echo "Setting up Wings auto-configuration..."
    cat << 'EOF' > /tmp/ptero_wings.exp
#!/usr/bin/expect -f
set timeout -1
set NODE_FQDN [lindex $argv 0]
set EMAIL [lindex $argv 1]

spawn bash -c "bash <(curl -s https://pterodactyl-installer.se)"

expect "Input 0-6:"
send "1\r"

expect {
    "Are you sure you want to proceed?" {
        send "y\r"
        expect "configure UFW"
        send "y\r"
    }
    "configure UFW" {
        send "y\r"
    }
}

expect "configure a user for database hosts"
send "y\r"

expect "Enter the panel address"
send "\r"

expect {
    "configure HTTPS using Let's Encrypt" {
        send "y\r"
        expect "FQDN of this node"
        send "$NODE_FQDN\r"
        expect "email address for Let's Encrypt:"
        send "$EMAIL\r"
        expect {
            "I agree that this HTTPS request is performed" {
                send "y\r"
                expect "Proceed with installation"
                send "y\r"
            }
            "Proceed with installation" {
                send "y\r"
            }
        }
    }
    "email address for Let's Encrypt:" {
        send "$EMAIL\r"
        expect {
            "I agree that this HTTPS request is performed" {
                send "y\r"
                expect "Proceed with installation"
                send "y\r"
            }
            "Proceed with installation" {
                send "y\r"
            }
        }
    }
    "Proceed with installation" {
        send "y\r"
    }
}

expect eof
EOF
    chmod +x /tmp/ptero_wings.exp
    /tmp/ptero_wings.exp "$NODE_FQDN" "$EMAIL"

    echo "Installation Complete!"

elif [ "$choice" == "2" ]; then
    echo "Uninstalling Pterodactyl Panel..."
    systemctl stop pteroq
    systemctl stop wings
    rm -rf /var/www/pterodactyl
    rm -rf /etc/pterodactyl
    rm -f /usr/local/bin/wings
    apt remove -y mariadb-server nginx php-fpm redis-server
    apt autoremove -y
    echo "Uninstallation complete."

elif [ "$choice" == "3" ]; then
    echo "Installing Reviactyl Panel..."
    bash <(curl -s https://raw.githubusercontent.com/Angelillo15/MinecraftPurpleTheme/main/install.sh)
    
    cd /var/www/pterodactyl
    rm -rf *
    curl -Lo panel.tar.gz https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    php artisan migrate --seed --force
    chown -R www-data:www-data /var/www/pterodactyl/*
    sudo systemctl restart pteroq.service
    echo "Reviactyl Panel installed successfully!"

else
    echo "Invalid option selected. Exiting."
fi
