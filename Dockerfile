# Start with a basic image that has some common vulnerabilities
FROM ubuntu:20.04

# Install basic utilities and vulnerable services
RUN apt-get update && apt-get install -y \
    apache2 \
    mysql-server \
    python3 \
    python3-pip \
    openssh-server \
    netcat \
    curl \
    vim \
    sudo \
    nmap \
    && apt-get clean

# Set up a vulnerable version of Python application with a simple vulnerability
RUN echo 'from flask import Flask\napp = Flask(__name__)\n@app.route("/")\ndef index():\n    return "Vulnerable App!"\napp.run(host="0.0.0.0", port=5000)' > /app.py \
    && pip3 install flask

# Set up a weak SSH configuration
RUN mkdir -p /var/run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:toor' | chpasswd

# Expose ports for vulnerable services
EXPOSE 80 3306 22 5000

# Set up Apache with some default misconfigurations
RUN echo "<Directory /var/www/html>\n  Options Indexes FollowSymLinks\n  AllowOverride None\n  Require all granted\n</Directory>" > /etc/apache2/sites-available/000-default.conf \
    && echo 'DocumentRoot /var/www/html' > /etc/apache2/apache2.conf \
    && echo '<h1>Welcome to the Vulnerable Web App!</h1>' > /var/www/html/index.html \
    && service apache2 start

# Start MySQL and Flask app (deliberately unprotected)
RUN service mysql start && \
    mysql -e "CREATE DATABASE testdb;" && \
    mysql -e "CREATE USER 'test'@'%' IDENTIFIED BY 'testpass';" && \
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'test'@'%';" && \
    mysql -e "FLUSH PRIVILEGES;" && \
    python3 /app.py &

# Start the SSH service
CMD service apache2 start && service mysql start && /usr/sbin/sshd -D

WORKDIR /root
RUN curl -L https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh > linpeas.sh && chmod +x linpeas.sh

