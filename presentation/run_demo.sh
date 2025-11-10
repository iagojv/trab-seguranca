#!/usr/bin/env bash
set -euo pipefail

# run_demo.sh
# Orquestrador host-side para apresentação:
# 1) Reconhecimento (nmap)
# 2) Dispara brute-force didático (no attacker)
# 3) Mostra resultados e logs
# 4) PAUSA: espera intervenção manual do apresentador para aplicar hardening
# 5) Após confirmação, realiza testes pós-hardening

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_DIR="$ROOT_DIR/shared"
ATTACKER_IP="192.168.56.20"
VICTIM_IP="192.168.56.10"
BRUTE_SCRIPT="/home/vagrant/attack_scripts/brute_force.sh"
BRUTE_WORDLIST="$SHARED_DIR/wordlists/passwords.txt"
ATTACKER_LOG="$SHARED_DIR/attacker_results/bruteforce_result.log"

# Helper for visual separation
sep() { echo; echo "============================================================"; echo; }

echo "Presentation orchestrator - starting"
echo "Project root: $ROOT_DIR"
echo "Shared dir: $SHARED_DIR"
sep

# Step 0: prechecks
echo "[CHECK] Ensure VMs are up..."
vagrant status --machine-readable | grep ",state," | sed -E 's/^[^,]*,([^,]*),([^,]*),([^,]*),.*/\1: \3/' || true
echo "[CHECK] Ensure shared folders exist on host"
mkdir -p "$SHARED_DIR/attacker_results"
mkdir -p "$SHARED_DIR/victim_logs"
mkdir -p "$SHARED_DIR/wordlists"

# Create a small demo wordlist if not exists (won't overwrite)
if [ ! -f "$BRUTE_WORDLIST" ]; then
  cat > "$BRUTE_WORDLIST" <<'EOF'
123456
password
prof123
toor
admin
EOF
  echo "[INFO] demo wordlist created at $BRUTE_WORDLIST"
fi

sep
echo "[STEP 1] Reconhecimento: nmap a partir da VM attacker (para demo)"
echo "Running: vagrant ssh attacker -c \"nmap -sV -p 22,2222 $VICTIM_IP\""
vagrant ssh attacker -c "nmap -sV -p 22,2222 $VICTIM_IP" || true

sep
echo "[STEP 2] Executando brute-force didático dentro da VM attacker"
echo "O script tentará até 10 senhas do wordlist e escreverá resultados em $ATTACKER_LOG"
echo "Running: vagrant ssh attacker -c \"$BRUTE_SCRIPT $VICTIM_IP $BRUTE_WORDLIST\""

vagrant ssh attacker -c "$BRUTE_SCRIPT $VICTIM_IP $BRUTE_WORDLIST" || true

sep
echo "[STEP 3] Exibindo resultados do ataque (do host)"
if [ -f "$SHARED_DIR/attacker_results/found_password.txt" ]; then
  echo "[RESULT] Senha encontrada:"
  cat "$SHARED_DIR/attacker_results/found_password.txt"
else
  echo "[RESULT] Nenhuma senha encontrada (nos primeiros 10 tries) — ver $ATTACKER_LOG para detalhes"
fi
echo
echo "Últimos logs do brute-force:"
tail -n 40 "$ATTACKER_LOG" || true

sep
echo "[PAUSA] Agora é a hora de aplicar o HARDENING manualmente (por segurança pede-se intervenção manual)."
echo "No host, execute (EXEMPLO):"
echo "  vagrant ssh victim -c \"sudo bash /vagrant/provision/hardening_victim.sh\""
echo
echo "OU aplique manualmente os passos de hardening desejados. NÃO execute o comando abaixo automaticamente sem consentimento."
echo
read -p "Depois de aplicar o hardening, pressione ENTER para continuar (ou Ctrl+C para abortar)."

sep
echo "[STEP 4] Testes pós-hardening"
echo "1) verificar sshd_config na victim:"
vagrant ssh victim -c "sudo grep -E 'PasswordAuthentication|PermitRootLogin|Port|AllowUsers' /etc/ssh/sshd_config -n" || true

echo "2) checar ufw e fail2ban status:"
vagrant ssh victim -c "sudo ufw status verbose || true; sudo fail2ban-client status sshd || true" || true

echo "3) tentar conectar via senha (deve falhar) e por chave (se copiada)"
echo "Tentando conexão por senha (esperado: falha):"
vagrant ssh attacker -c "ssh -o ConnectTimeout=5 -o BatchMode=no professor@$VICTIM_IP echo OK" || echo "[EXPECTED] conexão por senha falhou (Permission denied ou connect timeout)."

echo "Tentando conexão por chave na porta 2222 (se chave estiver instalada):"
vagrant ssh attacker -c "ssh -i ~/.ssh/id_demo -o StrictHostKeyChecking=no -p 2222 professor@$VICTIM_IP echo OK" || echo "[INFO] conexão por chave falhou ou não configurada."

sep
echo "Demo concluída. Verifique shared/ para resultados e logs."
echo "Lembrete: tudo feito em rede isolada. Não execute esses scripts em redes reais."

