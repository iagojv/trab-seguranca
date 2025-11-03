# Laboratório de Segurança de Redes — trab-seguranca

Este repositório contém um pequeno laboratório Vagrant/VirtualBox com duas VMs:

- `victim` (IP: 192.168.56.10) — VM alvo, inicialmente configurada com vulnerabilidades intencionais.
- `attacker` (IP: 192.168.56.20) — VM atacante com ferramentas de análise.

Pasta sincronizada do host: `./shared` → `/vagrant_shared` nas VMs.

---

## Pré-requisitos

- Git
- Vagrant (recomendado >= 2.2.x)
- VirtualBox (compatível com a versão do Vagrant)
- Conexão com a Internet (para baixar a box `ubuntu/focal64` na primeira execução)

---

## Estrutura principal

- `Vagrantfile` — define as VMs `victim` e `attacker`, rede privada e pasta sincronizada `./shared`.
- `provision/provision_victim.sh` — prepara a VM vítima (intencionalmente vulnerável: senhas fracas, SSH com senha e root habilitado).
- `provision/provision_attacker.sh` — instala ferramentas (nmap, curl, etc.) e prepara diretório `/vagrant_shared/attacker_results`.
- `provision/hardening_victim.sh` — script opcional para endurecer a VM vítima (desabilita root/password auth, muda porta SSH, instala fail2ban/ufw, etc.).
- `shared/` — pasta do host compartilhada com as VMs (deve existir antes de `vagrant up`).

---

## Passos rápidos para executar o ambiente

1. Certifique-se de que a pasta `shared/` existe na raiz do projeto (crie se necessário):

```powershell
New-Item -ItemType Directory -Path .\shared\attacker_results -Force
New-Item -ItemType Directory -Path .\shared\victim_logs -Force
```

2. Subir as VMs e provisionar:

```powershell
vagrant up
```

3. Verificar status e conectar:

```powershell
vagrant status
vagrant ssh victim
vagrant ssh attacker
```

4. Dentro da VM `victim`, verifique `/vagrant_shared` e arquivos de prova:

```bash
ls -la /vagrant_shared
ls -la /vagrant_shared/victim_logs
cat /home/professor/relatorio_institucional.txt
```

5. Aplicar o hardening (opcional — ATENÇÃO às chaves SSH):

```bash
# dentro da VM victim
sudo bash /vagrant/provision/hardening_victim.sh
```

**Observação importante:** o `hardening_victim.sh` desabilita PasswordAuthentication e PermitRootLogin. Antes de rodá-lo, certifique-se de ter acesso por chave pública (coloque a chave pública em `/root/.ssh/authorized_keys` ou no usuário `professor`) para não se trancar fora.

---

## Parar / destruir

```powershell
vagrant halt          # parar VMs
vagrant destroy -f    # destruir VMs
```

---

## Git e segurança

- Este repositório agora adiciona `.gitignore` com `.vagrant/` para evitar commitar metadados e chaves privadas do Vagrant.
- Se chaves privadas foram commitadas anteriormente (ex.: `.vagrant/machines/*/virtualbox/private_key`), você deve rotacionar/substituir essas chaves e considerar limpar o histórico do Git.

---

## Como limpar o histórico para remover arquivos sensíveis (opcional, destrutivo)

Existem duas abordagens comuns:

1. **BFG Repo-Cleaner (mais simples):**
   - Instalar o BFG (Java) e executar:
     ```bash
     # criar um clone "espelho"
     git clone --mirror https://github.com/SEU_USUARIO/SEU_REPO.git
     # remover arquivos/pastas específicos
     java -jar bfg.jar --delete-folders .vagrant --delete-files "private_key" repo.git
     cd repo.git
     git reflog expire --expire=now --all && git gc --prune=now --aggressive
     git push --force
     ```
   - BFG é rápido e simples para remover arquivos por nome/pasta.

2. **git filter-repo (recomendado atualmente):**
   - Instalar `git-filter-repo` (por exemplo, via pip) e executar no clone normal:
     ```bash
     git clone https://github.com/SEU_USUARIO/SEU_REPO.git
     cd SEU_REPO
     # remover a pasta .vagrant inteira do histórico
     git filter-repo --invert-paths --path .vagrant
     # ou remover arquivos nomeados (ex.: private_key)
     git filter-repo --path-glob "**/private_key" --invert-paths
     git push --force --all
     git push --force --tags
     ```

ATENÇÃO: ambos os métodos reescrevem o histórico. Você deverá forçar o push (`--force`) e avisar colaboradores — eles precisarão re-clonar ou rebasear suas cópias.

Se quiser, posso executar a limpeza do histórico por você — mas antes preciso da sua confirmação explícita, porque isso mudará a história e exigirá um push forçado.

---

## Recomendações finais

- Nunca commit chaves privadas em repositórios públicos.
- Mantenha este laboratório isolado da rede pública.
- Se precisar, eu posso: 1) executar a limpeza do histórico (com sua confirmação), 2) rotacionar chaves locais, 3) criar instruções adicionais.

---

Se quiser que eu prossiga e execute a limpeza do histórico (removendo os arquivos `.vagrant` do histórico remoto), confirme que posso reescrever o histórico e forçar o push — eu executarei os passos necessários e documentarei o processo.  
