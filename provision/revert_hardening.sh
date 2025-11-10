#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo ">> Revertendo configurações de hardening... <<"

# 1) Voltar root login e autenticação por senha
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 2) Voltar porta SSH para 22
sed -i 's/^Port .*/Port 22/' /etc/ssh/sshd_config

# 3) Remover restrição de usuários (AllowUsers)
sed -i '/^AllowUsers/d' /etc/ssh/sshd_config

# 4) Desativar e remover fail2ban
systemctl stop fail2ban || true
apt-get purge -y fail2ban || true

# 5) Resetar firewall UFW
ufw --force reset || true

# 6) Reinstalar e reconfigurar ssh
apt-get install -y openssh-server
systemctl enable ssh
systemctl restart ssh

# 7) Repor senhas fracas (pra demo)
echo "professor:prof123" | chpasswd
echo "root:toor" | chpasswd

echo ">> Hardening revertido com sucesso! <<"
echo "Reversão feita em $(date)" > /vagrant_shared/revert_done.txt

